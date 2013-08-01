<%@ Page Language="c#" Src="Searcharoo.cs" %>
<%@ import Namespace="System.Text" %>
<%@ import Namespace="System.Text.RegularExpressions" %>
<%@ import Namespace="System" %>
<%@ import Namespace="System.Net" %>
<%@ import Namespace="Searcharoo.Net" %>
<script runat="server">

    ///////////////////////////////////////////////
    //
    // Searcharoo.NET Version 2 alpha
    //
    ///////////////////////////////////////////////

    protected string startingUrl = "";
    protected ArrayList visited = new ArrayList();
    protected Hashtable visitedH = new Hashtable();
    protected int count=0;

    protected void Page_Load (object sender, System.EventArgs e) {
        // don't allow this page to index itself 
        if (Request.UserAgent.ToLower().IndexOf("searcharoo") >0 ) {Response.Clear();Response.End();return;}
        startingUrl   = URLinputBox.Text;
    }

    Catalog m_catalog ;
    protected void getURLInfo_Click (object sender, System.EventArgs e) {

        WebClient objWebClient = new WebClient();

        string strURL = URLinputBox.Text;
        startingUrl   = URLinputBox.Text;

        UTF8Encoding objUTF8 = new UTF8Encoding();

        m_catalog = new Catalog();

        parseUrl (strURL, objUTF8, objWebClient);

        Cache["Searcharoo_Catalog"] = m_catalog;
        Response.Write ("\n\nAdded to Cache!<hr>");

        return;
    } // getURLInfo_Click


    string fileContents="";
    string fileurl="";
    string filepath=""; string[] filepathA;
    string filetitle="";
    long   filesize =0;
    string filedesc="";

    public void parseUrl (string url, UTF8Encoding enc, WebClient browser) {

        if (++count > 200) return;
        if (visited.Contains(url)) {
            Response.Write ("<br><font size=-2>&nbsp;&nbsp;"+ url +" already spidered</font>");
        } else {
            visited.Add(url);
            try {
                fileContents = enc.GetString(browser.DownloadData(url));

                ParsedHtmlData pmd = ParseHtmlData1(url, fileContents);

                Response.Write ("<p><b>" + pmd.Title + "</b>" + pmd.Url);


                // ### Get the file SIZE ###
                filesize = fileContents.Length;

                    // ### Now remove HTML, convert to array, clean up words and index them ###
                fileContents = stripHtml (fileContents);

                Regex r = new Regex(@"\s+");            //remove all whitespace
                string wordsOnly = stripHtml(fileContents);

                // ### If no META DESC, grab start of file text ###
                if (null==filedesc || String.Empty==filedesc) {
                    if (wordsOnly.Length > 250)
                    filedesc = wordsOnly.Substring(0, 250);
                    else if (wordsOnly.Length > 50)
                        filedesc = wordsOnly.Substring(0, 50);
                    else
                        filedesc = "";
                }

                wordsOnly = r.Replace(wordsOnly, " "); // COMPRESS ALL WHITESPACE into a single space, seperating words
                string [] wordsOnlyA = wordsOnly.Split(' ');

                File infile = new File (pmd.Url
                                    , pmd.Title
                                    , filedesc
                                    , DateTime.Now
                                    , filesize) ;

                // ### Loop through words in the file ###
                int i = 0;
                string key = "";
                string val = "";
                string pos = "";

                foreach (string word in wordsOnlyA) {
                    key = word.Trim(' ', '?','\"', ',', '\'', ';', ':', '.', '(', ')').ToLower();
                    m_catalog.Add (key, infile, i);
                    i++;
                } // foreach
                Response.Write (" parsed " + i.ToString() + " words<br>");
                Response.Flush();


                Response.Flush();
                if (null != pmd.LocalLinks)
                foreach (object link in pmd.LocalLinks) {
                    parseUrl (Convert.ToString(link), enc, browser);
                }

            } catch (Exception ex) {
                Response.Write ("<br><font size=-2><b style=color:red>"+ url +"</b> download failed " + ex.Message +"</font>");
            }
        }
    }

    // Storage for parsed HTML data returned by ParsedHtmlData();
    public struct ParsedHtmlData {
        public string Url;

        public string Title;

        public string Description;

        public string Html;

        public ArrayList LocalLinks;
        public ArrayList ExternalLinks;

        public override string ToString() {
        string linkstring = "";

        foreach (object link in LocalLinks) {
            linkstring += Convert.ToString(link) + "<br>";
        }

        return Title + " " + Description + " " + linkstring + "<hr>" + Html;
        }
    }


    // http://www.experts-exchange.com/Programming/Programming_Languages/C_Sharp/Q_20848043.html
    public ParsedHtmlData ParseHtmlData1( string url, string htmlData ) {

        ParsedHtmlData pmd = new ParsedHtmlData();

        pmd.Url           = url;

        pmd.Title         = Regex.Match(htmlData, @"(?<=<title>).*?(?=</title>)", RegexOptions.IgnoreCase|RegexOptions.ExplicitCapture).Value;

        pmd.Description   = Regex.Match(htmlData, @"(?<=<meta\s+name=""description""\s+content="").*?(?=""\s*/?>)", RegexOptions.IgnoreCase|RegexOptions.ExplicitCapture).Value;

        pmd.Html          = htmlData;

        StringBuilder strTextBuilder=new StringBuilder();

        strTextBuilder.Append("<br>LINKS:<br>");

        string link="";

        ArrayList linkLocal    = new ArrayList();
        ArrayList linkExternal = new ArrayList();
        foreach (Match match in Regex.Matches(htmlData
                , @"(?<=<(a|area)\s+href="").*?(?=""\s*/?>)"
                , RegexOptions.IgnoreCase|RegexOptions.ExplicitCapture)) {

            link = match.Value;

            int spacePos = link.IndexOf(' ');
            int quotePos = link.IndexOf('"');

            int chopPos = (quotePos<spacePos?quotePos:spacePos);

            if (chopPos > 0) {
                link = link.Substring(0,chopPos);
            }

            if ( (link.Length > 8) && (link.Substring(0, 7).ToLower() == "http://") ) {
                linkExternal.Add(link) ;
                Response.Write (" - ");
                //linkLocal.Add(match.Value);
            } else {
                link = startingUrl + link;
                linkLocal.Add(link);
                Response.Write (" + ");
            }


            strTextBuilder.Append(link + "</br>");

        }
        pmd.LocalLinks = linkLocal;
        pmd.ExternalLinks = linkExternal;

        foreach (Match match in Regex.Matches(htmlData
                , @"<(p|h[1-6]|a)[^>]*>.*?</\1>"
                , RegexOptions.IgnoreCase|RegexOptions.Singleline)) {
            //strTextBuilder.Append(match.Value);
            strTextBuilder.Append(Regex.Replace(match.Value, @"<[^>]*>", ""));
            //strTextBuilder.Append(Regex.Replace(match.Value, @"<(p|h[1-6]|font)[^>]*>.*?</\1>", ""));
        }

        return pmd;
    }


    // Stripping HTML
    // http://www.4guysfromrolla.com/webtech/042501-1.shtml
    protected string stripHtml(string strHtml) {
        //Strips the HTML tags from strHTML
        System.Text.RegularExpressions.Regex objRegExp = new System.Text.RegularExpressions.Regex("<(.|\n)+?>");

        string strOutput;
        //objRegExp.IgnoreCase = true;
        //objRegExp.Global = true;
        //objRegExp.Pattern = "<(.|\n)+?>";

        //Replace all HTML tag matches with the empty string
        strOutput = objRegExp.Replace(strHtml, "");

        //Replace all < and > with &lt; and &gt;
        strOutput = strOutput.Replace("<", "&lt;");
        strOutput = strOutput.Replace(">", "&gt;");

        return strOutput;
        objRegExp = null;
    }

</script>
<html>
<head>
    <title>Spideroo</title>
    <meta http-equiv="robots" content="noindex,nofollow">
    <style type="text/css">
    body{margin:0px 0px 0px 0px;font-family:trebuchet ms, verdana, sans-serif;background-color:white;}
	</style>
</head>
<body>
    Spideroo
    <form id="Form1" method="post" runat="server">
        <asp:textbox id="URLinputBox" text="http://localhost:8081/" size="40" Runat="server"></asp:textbox>
        <asp:button id="getURLInfo" onclick="getURLInfo_Click" Runat="server" Text="Get Info"></asp:button>
        <br />

    </form>
</body>
</html>
