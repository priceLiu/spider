<%@ Page Language="c#" autoeventwireup="true" Src="Searcharoo.cs" %>
<%@ import Namespace="System" %>
<%@ import Namespace="System.Xml.Serialization" %>
<%@ import Namespace="System.Collections.Specialized" %>
<%@ import Namespace="Searcharoo.Net" %>
<script runat="server">

    /*
    * (c) 2004 Craig Dunn - ConceptDevelopment.NET
    * 2-July-04
    *
    * More info:
    *    http://users.bigpond.com/conceptdevelopment/search/searcharooV2/
    */
    /// <summary>Displayed in HTML</summary>
    public int wordcount;
    /// <summary>Displayed in HTML</summary>
    public string errormsg = String.Empty;
    /// <summary>Get from Cache</summary>
    Catalog m_catalog = null;
    
    /// <summary>
    /// Html string containing the stylesheet
    /// </summary>
    protected string stylesheet = @"
    <meta http-equiv=""robots"" content=""none"">
    <style type=""text/css"">
        body{margin:10px 10px 10px 10px;background-color:white;}
        body,td,a{font-family:trebuchet ms, verdana, arial, sans-serif;}
        .heading{font-size:xx-large;font-weight:bold;color:darkgrey;}
        .subheading{font-size:large;font-weight:bold;color:darkgrey;}
        .copyright{font-size:xx-small;}
    </style>";
    
    /// <summary>
    /// Html string with the SearchForm that is displayed at the top of the results page
    /// </summary>
    protected string WriteSearchForm (string word, int count) { return @"<form method=""get"" id=""top"" action=""SearcharooToo.aspx"">
        <center>
        <p class=""subheading""><font color=""darkgray"">Search</font><font color=red>a</font><font color=blue>r</font><font color=green>o</font><font color=orange>o</font> <font color=darkgray>Too</font></p>
    
        <table cellspacing=0 cellpadding=4 frame=box bordercolor=#dcdcdc rules=none style=""BORDER-COLLAPSE: collapse"" width=""100%"">
            <tr>
                <td>
                <p>Search for :
                    <input type=input name=""searchfor"" id=""searchfor"" width=""400"" value=""" + word + @"""/>
                    <input type=submit value=""Searcharoo!"" class=""button"" />
                </p>
                </td>
            </tr>
            <tr><td><p class=""copyright"">Searching "+ count +@" words</p></td></tr>
        </table>
        </center>
    </form>";}
    
    /// <summary>
    /// Results page footer, with Search form and off-site links to ConDev
    /// </summary>
    protected string WriteFooter (string word, int count) { return @"<form method=""get"" id=""bottom"" action=""SearcharooToo.aspx"">
        <center>
        <table cellspacing=0 cellpadding=4 frame=box bordercolor=#dcdcdc rules=none style=""BORDER-COLLAPSE: collapse"" width=""100%"">
            <tr>
                <td>
                <p>Search for :
                    <input type=input name=""searchfor"" id=""searchfor"" width=""400"" value=""" + word + @"""/>
                    <input type=submit value=""Searcharoo!"" class=""button"" />
                </p>
                </td>
            </tr>
            <tr><td><a href=""http://www.searcharoo.net/"">Searcharoo.Net</a> - <a href=""http://www.conceptdevelopment.net/"">ConceptDevelopment.Net</a></td></tr>
            <tr><td><p class=""copyright"">&copy;2004 <a href=""http://www.conceptdevelopment.net/"">ConceptDevelopment.Net</a> - Searching "+ count +@" words</p></td></tr>
        </table>
        </center>
    </form>";}
    
    /// <summary>
    /// ALL processing happens here, since we are not using ASP.NET controls or events.
    /// Page_Load will:
    /// * check the Cache for a catalog to use (and if not, Server.Transfer to the Spider)
    /// * check the QueryString for search arguments (and if so, do a search)
    /// * otherwise just show the HTML of this page - a blank search form
    /// </summary>
    public void Page_Load () {
        if (Request.UserAgent.ToLower().IndexOf("searcharoo") >0 ) {Response.Clear();Response.End();return;}
        try {
            // see if there is a catalog object in the cache
            m_catalog = (Catalog)Cache["Searcharoo_Catalog"];
            wordcount = m_catalog.Length; // if so, get the wordcount
        } catch (Exception ex) {
            // otherwise, we'll need to build the catalog
            Response.Write ("Catalog object unavailable : building a new one ! <!--" + ex.ToString() + "-->");
            m_catalog = null; // in case
        }
        if (null == m_catalog) {
            Server.Transfer("SearcharooSpider.aspx");
            m_catalog = (Catalog)Cache["Searcharoo_Catalog"];
        } else if  (m_catalog.Length == 0) {
            Server.Transfer("SearcharooSpider.aspx");
            m_catalog = (Catalog)Cache["Searcharoo_Catalog"];
        }
    
        if ((null!=Request.QueryString["searchfor"]) && (null != m_catalog) ) {
            // Assume Catalog exists in Cache
            string searchterm = String.Empty;
            string [] searchTermA = null;
    
            searchterm = Request.QueryString["searchfor"].ToString().Trim(' ');
            /****** Too *********/
            Regex r = new Regex(@"\s+");            //remove all whitespace
            searchterm = r.Replace(searchterm, " ");// to a single space
            searchTermA = searchterm.Split(' ');// then split
            for (int i = 0; i < searchTermA.Length; i++) {
                searchTermA[i] = searchTermA[i].Trim(' ', '?','\"', ',', '\'', ';', ':', '.', '(', ')').ToLower();
            }
    
            if (searchterm == String.Empty) {
                // After trimming the search term, it was found to be empty!
                // Show this message and redisplay the blank Search page
                errormsg = "<br>Please type a word (or words) to search for";
            } else {
                DateTime start = DateTime.Now;  // to show 'time taken' to perform search
    
                Response.Write ("<html><title>Searcharoo results for: "+searchterm+"</title>");
                Response.Write (stylesheet);
                Response.Write ("<body style='font-family:tahoma;font-size:x-small'>");
    
                Response.Write (WriteSearchForm (searchterm, wordcount));
    
                // Array of arrays of results that match ONE of the search criteria
                Hashtable[] searchResultsArrayArray = new Hashtable[searchTermA.Length];
                // finalResultsArray is populated with pages that *match* ALL the search criteria
                HybridDictionary finalResultsArray = new HybridDictionary();
                // Html output string
                string matches="";
                bool botherToFindMatches = true;
                int indexOfShortestResultSet = -1, lengthOfShortestResultSet = -1;
    
                for (int i = 0; i < searchTermA.Length; i++) {
                    searchResultsArrayArray[i] = m_catalog.Search (searchTermA[i].ToString());  // ##### THE SEARCH #####
                    if (null == searchResultsArrayArray[i]) {
                    matches += searchTermA[i] + " <font color=gray style='font-size:xx-small'>(not found)</font> ";
                    botherToFindMatches = false; // if *any one* of the terms isn't found, there won't be a 'set' of matches
                    } else {
                        int resultsInThisSet = searchResultsArrayArray[i].Count;
                        matches += "<a href=\"?searchfor="+searchTermA[i]+"\">"
                                + searchTermA[i]
                                + "</a> <font color=gray style='font-size:xx-small'>(" + resultsInThisSet + ")</font> ";
                        if ( (lengthOfShortestResultSet == -1) || (lengthOfShortestResultSet > resultsInThisSet) ) {
                        indexOfShortestResultSet  = i;
                        lengthOfShortestResultSet = resultsInThisSet;
                        }
                    }
                }
                Response.Write ("<h4>Results for: ");
                Response.Write (matches);
    
                // Find the common files from the array of arrays of documents
                // matching ONE of the criteria
                if (botherToFindMatches) {                                          // all words have *some* matches
                //for (int c = 0; c < searchResultsArrayArray.Length; c++) {        // for each result set [NOT required, but maybe later if we do AND/OR searches)
                    int c = indexOfShortestResultSet;                               // loop through the *shortest* resultset
                    Hashtable searchResultsArray = searchResultsArrayArray[c];
    
                    if (null != searchResultsArray)
                    foreach (object foundInFile in searchResultsArray) {            // for each file in the *shortest* result set
                        DictionaryEntry fo = (DictionaryEntry)foundInFile;          // find matching files in the other resultsets
    
                        int matchcount=0, totalcount=0, weight=0;
    
                        for (int cx = 0; cx < searchResultsArrayArray.Length; cx++) {
                            totalcount+=(cx+1);                                // keep track, so we can compare at the end (if term is in ALL resultsets)
                            if (cx == c) {                                     // current resultset
                                matchcount += (cx+1);                          // implicitly matches in the current resultset
                                weight += (int)fo.Value;                       // sum the weighting
                            } else {
                                Hashtable searchResultsArrayx = searchResultsArrayArray[cx];
                                if (null != searchResultsArrayx)
                                foreach (object foundInFilex in searchResultsArrayx) {        // for each file in the result set
                                    DictionaryEntry fox = (DictionaryEntry)foundInFilex;
                                    if (fo.Key == fox.Key) {                                  // see if it matches
                                        matchcount += (cx+1);                  // and if it matches, track the matchcount
                                        weight += (int)fox.Value;               // and weighting; then break out of loop, since
                                        break;                                 // no need to keep looking through this resultset
                                    }
                                } // foreach
                            } // if
                        } // for
                        if ( (matchcount>0) && (matchcount == totalcount) ) { // was matched in each Array
                            // we build the finalResults here, to pass to the formatting code below
                            // - we could do the formatting here, but it would mix up the 'result generation'
                            // and display code too much
                            fo.Value = weight; // set the 'weight' in the combined results to the sum of individual document matches
                            if ( !finalResultsArray.Contains (fo.Key) ) finalResultsArray.Add ( fo.Key, fo);
                        } // if
                    } // foreach
                } // if
                //} // for
    
                // Time taken calculation
                Int64 ticks = DateTime.Now.Ticks - start.Ticks;
                TimeSpan taken = new TimeSpan (ticks);
                Response.Write ("&nbsp; <font size=1>");
                if (taken.Seconds > 0)
                    Response.Write (taken.Seconds + " seconds</font>");
                else if (taken.TotalMilliseconds > 0)
                    Response.Write (Convert.ToInt32(taken.TotalMilliseconds) + " milliseconds</font>");
                else
                    Response.Write ("less than 1 millisecond</font>");
                Response.Write ("</font>");
                Response.Write ("</h4>");
    
                // The preceding 80 lines (or so) replaces this single line from Version 1
                //       Hashtable searchResultsArray = m_catalog.Search (searchterm);
                // when only single-word-searches were supported. Look closely and you'll see this line
                // labelled #THE SEARCH# still in the code above...
    
                // Format the results
                //if (null != searchResultsArray) {
                if (finalResultsArray.Count > 0) {
                    // intermediate data-structure for 'ranked' result HTML
                    SortedList output = new SortedList (finalResultsArray.Count); // empty sorted list
                    DictionaryEntry fo;
                    File infile;
                    string result="";
                    // build each result row
                    foreach (object foundInFile in finalResultsArray.Keys) {
                        // build the HTML output in the sorted list, so the 'unsorted'
                        // searchResults are 'sorted' as they're added to the SortedList
    
                        infile = (File)foundInFile;
    
                        int rank = (int)((DictionaryEntry)finalResultsArray[foundInFile]).Value;
                        // Create the formatted output HTML
                        result = ("<a href=" + infile.Url + ">");
                        result += ("<b>" + (infile.Title==""?"&laquo; no title &raquo;":infile.Title) + "</b></a>");
                        result += (" <a href=" + infile.Url + " target=\"_TOP\" ");
                        result += ("title=\"open in new window\" style=\"font-size:xx-small\">&uarr;</a>");
                        result += (" <font color=gray>("+rank+")</font>");
                        result += ("<br>" + infile.Description + "..." ) ;
                        result += ("<br><font color=green>" + infile.Url + " - " + infile.Size);
                        result += ("bytes</font> <font color=gray>- " + infile.CrawledDate + "</font><p>" ) ;
    
                        int sortrank = (rank * -1); // multiply by -1 so larger score goes to the top
                        if (output.Contains(sortrank) ) { // rank exists; concatenate same-rank output strings
                            output[sortrank] = ((string)output[sortrank]) + result;
                        } else {
                            output.Add(sortrank, result);
                        }
                        result = ""; // clear string for next loop
                    }
                    // Now output to the HTML Response
                    foreach (object rows in output) { // Already sorted!
                        Response.Write ( (string)((DictionaryEntry)rows).Value );
                    }
                    Response.Write("<p>Matches: " + finalResultsArray.Count);
                } else {
                    Response.Write("<p>Matches: 0");
                }
                Response.Write ("<p><a href=#top>&uarr; top</a>");
    
                Response.Write (WriteFooter (searchterm, wordcount) );
                Response.End(); // Stop here - don't output the HTML in this file which is a blank form
                                // for when the page is first displayed
            } // if results
        } // QueryString AND catalog were present
    } // Page_Load

</script>
<html>
  <head>
    <title>Searcharoo.Net Version 2</title>
    <meta http-equiv="robots" content="none">
    <style type="text/css">
    body{margin:0px 0px 0px 0px;font-family:trebuchet ms, verdana, arial, sans-serif;background-color:white;}
    .heading{font-size:xx-large;font-weight:bold;color:darkgrey;filter:DropShadow (Color=#cccccc, OffX=5, OffY=5, Positive=true)}
    .copyright{font-size:xx-small;}
	</style>
</head>
    <body>
<form method="get" action="SearcharooToo.aspx">
    <center>
    <p class="heading"><font color=darkgray>Search</font><font color=red>a</font><font color=blue>r</font><font color=green>o</font><font color=orange>o</font> <font color=darkgray>Too</font></p>

    <table cellspacing="0" cellpadding="4" frame="box" bordercolor="#dcdcdc" rules="none" style="BORDER-COLLAPSE: collapse">
        <tr>
            <td>
            <p class="intro">Search for ...<br>
                <input name="searchfor" id="searchfor" size="40" /> <font color=red><%=errormsg%></font>
            </p>
            </td>
        </tr>
        <tr><td align="center"><input type="submit" value="Searcharoo!" class="button" /></td></tr>

        <tr><td><a href="http://www.searcharoo.net/">Searcharoo.Net</a> - <a href="http://www.conceptdevelopment.net/">ConceptDevelopment.Net</a></td></tr>

        <tr><td><p class="copyright">©2004 ConceptDevelopment.Net - Searching <%=wordcount%> words</p></td></tr>
    </table>
    </center>
</form>
    </body>
</html>
