<%@ Page Language="C#" autoeventwireup="true" Src="Searcharoo.cs" %>
<%@ import Namespace="System" %>
<%@ import Namespace="System.Xml.Serialization" %>
<%@ import Namespace="Searcharoo.Net" %>
<script runat="server">

    private string m_path;
    private string m_url;
    private string m_filter;

    /// <summary>Working variable for the catalog being built</summary>
    private Catalog m_catalog ;

        /// <summary>Look for settings, then start crawl</summary>
        public void Page_Load () {
            // don't allow this page to index itself 
            if (Request.UserAgent.ToLower().IndexOf("searcharoo") >0 ) {Response.Clear();Response.End();return;}
            // Get settings from web.config
            m_path = ConfigurationSettings.AppSettings["Searcharoo_PhysicalPath"];
            m_url = ConfigurationSettings.AppSettings["Searcharoo_VirtualRoot"];
            m_filter = ConfigurationSettings.AppSettings["Searcharoo_FileFilter"];
            // If not found in web.config, use defaults
            if (null == m_path) { // use the path of the search ASPX page
                m_path = Server.MapPath(".");
            }
            if (null == m_url) { // use the base url of the search ASPX page
                string[] subfolders = Request.ServerVariables["PATH_INFO"].Split('/');
                string path ="";
                for (int i = 0; i < (subfolders.Length - 1); i++) {
                   // check for 'empty' elements, to prevent double // in URL
                   if (null != subfolders[i] && String.Empty != subfolders[i]) path += "/" + subfolders[i];
                }
                m_url = "http://" + Request.ServerVariables["HTTP_HOST"] + path;
            }
            if (null == m_filter) { // default to HTML files
                m_filter = "*.html";
            }
            // Write config info to Trace (for debugging)
            string message = "Configuration:"
                         + "\nPath:   "+ m_path
                         + "\nFilter: "+ m_filter
                         + "\nUrl:    "+ m_url;
            // for debugging/information
            Trace.Write (message);
            // write HTML header
             Response.Write(@"<html>
             <head>
             <style type='text/css'>
                 BODY { color: #000000; background-color: white; font-family: trebuchet ms, verdana, arial, sans-serif; font-size:x-small; margin-left: 0px; margin-top: 0px; }
             </style>
             <title>Searcharoo Filesystem Crawl</title>
             </head>
             <body>
             <h3><font color=darkgray>Search</font><font color=red>a</font><font color=blue>r</font><font color=green>o</font><font color=yellow>o</font></h3>
             Generating the catalog - sorry for the inconvenience, it will only take a few minutes...<p>");
             // Build the catalog!
             BuildCatalog ();
             // Check if anything was found
             if (m_catalog.Length > 0) {
                 Response.Write ("<br>Finished - now you can search!<p>");
                 Server.Transfer ("Searcharoo.aspx");
             } else
                 Response.Write ("<br><p font='color:red'>Sorry, nothing was cataloged. Check the settings in web.config.</p>");
         } // Page_Load



         /// <summary> Start the recursive processing, and add result to Cache</summary>
         public void BuildCatalog () {

                 m_catalog = new Catalog();

                 CrawlCatalog (m_path, m_path);

                 // ### Put the catalog into the Cache ###
                 Cache["Searcharoo_Catalog"] = m_catalog;

                 Response.Write ("\n\nAdded to Cache!");
                 Response.Flush();
         } // BuildCatalog


         /// <summary>Stripping HTML, thanks to
         /// http://www.4guysfromrolla.com/webtech/042501-1.shtml</summary>
    protected string stripHtml(string strHtml) {
         //Strips the HTML tags from strHTML
         System.Text.RegularExpressions.Regex objRegExp
                 = new System.Text.RegularExpressions.Regex("<(.|\n)+?>");

         // Replace all tags with a space, otherwise words either side
         // of a tag might be concatenated
         string strOutput = objRegExp.Replace(strHtml, " ");

         // Replace all < and > with &lt; and &gt;
         strOutput = strOutput.Replace("<", "&lt;");
         strOutput = strOutput.Replace(">", "&gt;");

         return strOutput;
    }

         // variables used in recursive method CrawlCatalog
         string fileContents,fileurl, filepath;
         string[] filepathA;
         string filetitle="";
         long   filesize=0;
         string filedesc="";

         /// <summary>Crawl through a directory, processing files matching the pattern</summary>
         private void CrawlCatalog (string root, string path) {
             System.IO.DirectoryInfo m_dir = new System.IO.DirectoryInfo (path);
             // Look for matching files
             foreach (System.IO.FileInfo f in m_dir.GetFiles(m_filter)) {
                 Response.Write (DateTime.Now.ToString("t") + " " + path.Substring(root.Length) + @"\" + f.Name );Response.Flush();
                 fileurl = m_url + path.Substring(root.Length).Replace(@"\", "/") + "/" + f.Name;

                 System.IO.StreamReader reader = System.IO.File.OpenText  (path + @"\" + f.Name);
                 fileContents = reader.ReadToEnd();
                 reader.Close(); // now use the fileContents to build the catalog...

                 // ### Grab the <TITLE> ###
                 Match TitleMatch = Regex.Match(fileContents, "<title>([^<]*)</title>", RegexOptions.IgnoreCase | RegexOptions.Multiline );
                 filetitle = TitleMatch.Groups[1].Value;
                 // ### Parse out META data ###
                 Match DescriptionMatch = Regex.Match( fileContents, "<META NAME=\"DESCRIPTION\" CONTENT=\"([^<]*)\">", RegexOptions.IgnoreCase | RegexOptions.Multiline );
                 filedesc = DescriptionMatch.Groups[1].Value;
                 // ### Get the file SIZE ###
                 filesize = fileContents.Length;
                 // ### Now remove HTML, convert to array, clean up words and index them ###
                 fileContents = stripHtml (fileContents);


                 string wordsOnly = stripHtml(fileContents);

                 // ### If no META DESC, grab start of file text ###
                 if (null==filedesc || String.Empty==filedesc) {
                 if (wordsOnly.Length > 350)
                     filedesc = wordsOnly.Substring(0, 350);
                 else if (wordsOnly.Length > 100)
                     filedesc = wordsOnly.Substring(0, 100);
                 else
                     filedesc = wordsOnly; // file is only short!
                 }

                 Regex r = new Regex(@"\s+");           // remove all whitespace
                 wordsOnly = r.Replace(wordsOnly, " "); // compress all whitespace to one space
                 string [] wordsOnlyA = wordsOnly.Split(' '); // results in an array of words

                 // Create the object to represent this file (there will only ever be ONE instance per file)
                 File infile = new File (fileurl
                                     , filetitle
                                     , filedesc
                                     , DateTime.Now
                                     , filesize) ;

                 string val = "";
                 string pos = "";

    // ### Loop through words in the file ###
    int i = 0;     // Position of the word in the file (starts at zero)
    string key = ""; // the 'word' itself
    // Now loop through the words and add to the catalog
    foreach (string word in wordsOnlyA) {
        key = word.Trim(' ', '?','\"', ',', '\'', ';', ':', '.', '(', ')').ToLower();
        m_catalog.Add (key, infile, i);
        i++;
    } // foreach word in the file
                 Response.Write (" parsed " + i.ToString() + " words<br>");
                 Response.Flush();


             } // foreach matching file

             // Now recursively call this method for all subfolders
             foreach (System.IO.DirectoryInfo d in m_dir.GetDirectories()) {
                 CrawlCatalog (root, path + @"\" + d.Name);
             } // foreach folder
         } // CrawlCatalog


         /// <summary>A recursive function to look for matching files in
         /// a folder and its subfolders. The main method - CrawlCatalog -
         /// is based on this code (which is no longer used)</summary>
         [Obsolete]
         private void CrawlPath (string root, string path) {
             System.IO.DirectoryInfo m_dir = new System.IO.DirectoryInfo (path);
             // ### Look for matching files to summarise what will be catalogued ###
             foreach (System.IO.FileInfo f in m_dir.GetFiles(m_filter)) {
                 Response.Write (path.Substring(root.Length) + @"\" + f.Name + "<br>");
             } // foreach
             foreach (System.IO.DirectoryInfo d in m_dir.GetDirectories()) {
                 CrawlPath (root, path + @"\" + d.Name);
             } // foreach
         }

</script>
