<%@ Page Language="c#" Src="Searcharoo.cs" Debug="true" %>
<%@ import Namespace="System.Text" %>
<%@ import Namespace="System.Text.RegularExpressions" %>
<%@ import Namespace="System" %>
<%@ import Namespace="System.Net" %>
<%@ import Namespace="Searcharoo.Net" %>
<script runat="server">

    /*
    * (c) 2004 Craig Dunn - ConceptDevelopment.NET
    * 2-July-04
    *
    * More info:
    *    http://users.bigpond.com/conceptdevelopment/search/searcharooV2/
    */
    /// <summary>GLOBAL starting Uri - so we can check the Uri.Host again other links to determine if they're external</summary>
    protected Uri startingUri;
    /// <summary>Preferences</summary>
    protected int prefRequestTimeout=15, prefRecursionLimit=400;
    /// <summary>GLOBAL counter used to track recursion</summary>
    protected int count=0;
    /// <summary></summary>
    protected ArrayList visited = new ArrayList();
    /// <summary></summary>
    protected Hashtable visitedH = new Hashtable();
    /// <summary>working copy of a catalog, assigned to the Cache when populated</summary>
    protected Catalog m_catalog ;
    /// <summary>WARNING: setting PrintDebug to true results in VERY VERBOSE OUTPUT</summary>
    private bool PrintDebug = false;
    
    /// <summary>
    /// Every time this page is loaded it will attempt to re-build the catalog.
    /// This includes instances where it has been Server.Transfer'ed to by SearcharooToo.aspx
    /// (the search input page) when the catalog is null or empty.
    /// </summary>
    /// <remarks>
    /// Some of the references used when researching this page:
    ///
    /// C# and the Web: Writing a Web Client Application with Managed Code in the Microsoft .NET Framework - not that helpful...
    /// http://msdn.microsoft.com/msdnmag/issues/01/09/cweb/default.aspx
    ///
    /// Retrieving a List of Links & Images from a Web Page
    /// http://www.dotnetjunkies.com/Tutorial/1B219C93-7702-4ADF-9106-DFFDF90914CF.dcik
    /// </remarks>
    protected void Page_Load (object sender, System.EventArgs e) {
        // don't allow this page to index itself
        if (Request.UserAgent.ToLower().IndexOf("searcharoo") >0 ) {Response.Clear();Response.End();return;}
        // get web.config settings
        if (null != ConfigurationSettings.AppSettings["Searcharoo_RequestTimeout"]) {
            prefRequestTimeout = Convert.ToInt32(ConfigurationSettings.AppSettings["Searcharoo_RequestTimeout"]);
        }
        if (null != ConfigurationSettings.AppSettings["Searcharoo_VirtualRoot"]) {
            startingUri = new Uri (ConfigurationSettings.AppSettings["Searcharoo_VirtualRoot"].ToString() );
        } else {
            //startingUri = new Uri ("http://localhost:8080/"); // occasionally hardcode this for testing...
            startingUri = new Uri ("http://" + Request.ServerVariables["HTTP_HOST"]);
        }
    
        // Write config info to Trace (for debugging)
        string message = "Configuration:"
                        + "\nUri:   "+ startingUri.AbsoluteUri.ToString()
                        + "\nTimout: "+ prefRequestTimeout;
        // for debugging/information
        Trace.Write (message);
        // write HTML header
        Response.Write(@"<html>
        <head>
        <meta http-equiv=""robots"" content=""noindex,nofollow"">
        <style type='text/css'>
            BODY { color: #000000; background-color: white; font-family: trebuchet ms, verdana, arial, sans-serif; font-size:x-small; margin-left: 0px; margin-top: 0px; }
        </style>
        <title>Searcharoo Website Spider</title>
        </head>
        <body>
        <h3><font color=darkgray>Search</font><font color=red>a</font><font color=blue>r</font><font color=green>o</font><font color=orange>o</font> <font color=darkgray>Too</font></h3>
        Generating the catalog - sorry for the inconvenience, it will only take a few minutes...<p>");
        // Build the catalog!
        BuildCatalog (startingUri);
        // Check if anything was found
        if (m_catalog.Length > 0) {
            Response.Write ("<br>Finished - now you can search!<p>");
            Server.Transfer ("SearcharooToo.aspx");
        } else
            Response.Write ("<br><p font='color:red'>Sorry, nothing was cataloged at " + startingUri.AbsoluteUri.ToString() + ". Check the settings in web.config.</p>");
    } // Page_Load
    
    
    /// <summary>
    /// Start the cataloging process by instantiating the catalog
    /// object and calling Process() for the starting Url...
    /// </summary>
    /// <remarks>
    /// Alpha code used the System.Net.WebClient class...
    /// http://www.dotgnu.org/pnetlib-doc/System/Net/WebClient.html
    /// </remarks>
    protected void BuildCatalog (Uri startPageUri) {
        m_catalog = new Catalog();
        // create the 'root' document to start the search
        HtmlDocument htmldoc = new HtmlDocument (startPageUri);
        // does all the complex iterative page parsing here
        Process (htmldoc);
        htmldoc = null;
        // finished, add to cache
        Cache ["Searcharoo_Catalog"] = m_catalog;
        Response.Write ("\n\n<p>Added to <font color=blue>Cache [\"Searcharoo_Catalog\"]</font><hr>");
        return;
    } // BuildCatalog
    
    
    /// <summary>
    /// Recursive method that takes an HtmlDocument
    /// </summary>
    /// <remarks>
    /// This method was originally quite long, until code was factored out into
    /// * Download()
    /// * Parse()
    /// * Process()
    /// methods. Now it merely acts as the vehicle for grouping these methods and
    /// outputting progress/debugging information
    /// </remarks>
    /// <param name="htmldoc">
    /// HtmlDocument object with Uri property set. Data will be downloaded from this location
    /// and used to populate the other fields of the object, which will then be parsed and
    /// catalogued.
    /// </param>
    protected void Process (HtmlDocument htmldoc) {
        string filedesc="";
        long   filesize =0;
        int    wordcount=0;
    
        string url = htmldoc.Uri.AbsoluteUri;
    
        // Recursion can be turned off by setting prefRecursionLimit to -1
        if ((prefRecursionLimit > 0) && (count > prefRecursionLimit)) return;
    
        if (visited.Contains (url.ToLower())) {
            if (PrintDebug) Response.Write ("<br><font size=-2>&nbsp;&nbsp;"+ url +" already spidered</font>");
        } else {
            count++;
            visited.Add (url.ToLower());
            if (PrintDebug) Response.Write ("<br><font size=1>" + url + "</font>");
            Response.Flush();
            if (Download (htmldoc) ) {              // ### Download method below
                if (htmldoc.RobotIndexOK) {
                    Parse    (htmldoc);             // ### Parse method below
                    wordcount = Catalog (htmldoc);  // ### Catalog method below
                }
            }
            if (PrintDebug) Response.Write ("<p><b>" + htmldoc.Title + "</b><br>&nbsp;&nbsp;&nbsp;&nbsp;<font size=2>"
                + htmldoc.Url + "</font>"
                + (PrintDebug?htmldoc.Description:"")
                + " parsed " + wordcount + " words! <font color=red>"+ (htmldoc.RobotIndexOK?"Indexed":"Robot Excluded Index") +"</font><br>");
            else
                if (wordcount>0) Response.Write ("<br><b>" + htmldoc.Title + "</b> parsed " + wordcount + " words!");
    
            // ### Loop through the 'local' links in the document ###
            // ### and parse each of them recursively ###
            if (null != htmldoc.LocalLinks && htmldoc.RobotFollowOK) { // only if the Robot meta says it's OK
                foreach (object link in htmldoc.LocalLinks) {
                    try {
                        Uri linkToFollow = new Uri (htmldoc.Uri, link.ToString());
                        if (linkToFollow.Host == startingUri.Host) {
                            HtmlDocument hd = new HtmlDocument (linkToFollow);
                            Process (hd);
                            hd = null;
                        } else {
                            Response.Write ("<br><font color=red>" + linkToFollow.AbsoluteUri.ToString() + " not 'local' on host " + startingUri.Host + "</font>");
                        }
                    } catch (Exception ex) {
                        if (PrintDebug) Response.Write ("<br><font color=red>new Uri("+htmldoc.Uri + ", "+link.ToString()+") invalid : " +  ex.Message + "</font>");
                    }
                } // each link
            } // process local links
        } // not visited
    } // Process
    
    
    /// <summary>
    /// Actually grab the bytes from a Url and decode them into a string variable.
    /// </summary>
    /// <remarks>
    /// Alpha code used the System.Net.WebClient in this method, but was not configurable enough
    /// http://www.dotgnu.org/pnetlib-doc/System/Net/WebClient.html
    /// </remarks>
    protected bool Download (HtmlDocument htmldoc) {
        bool success = false;
        // Open the requested URL
        HttpWebRequest req = (HttpWebRequest) WebRequest.Create(htmldoc.Uri.AbsoluteUri);
        req.AllowAutoRedirect = true;
        req.MaximumAutomaticRedirections = 3;
        req.UserAgent = "Mozilla/6.0 (MSIE 6.0; Windows NT 5.1; Searcharoo.NET Robot)";
        req.KeepAlive = true;
        req.Timeout = prefRequestTimeout * 1000;
    
        // Get the stream from the returned web response
        System.Net.HttpWebResponse webresponse = null;
        try {
            webresponse = (HttpWebResponse) req.GetResponse();
        } catch(System.Net.WebException we) {
            //remote url not found, 404
            if (PrintDebug) Response.Write ("<br><font color=red>skipped  " + htmldoc.Uri + " response exception:" + we.Message + "</font>");
        }
        if (webresponse != null) {
            htmldoc.ContentType = webresponse.ContentType; // Parse out MimeType and Charset
            switch (htmldoc.MimeType.ToLower() ) {
                case "text/css":
                    // do not process CSS for now...
                    break;
                default:
                    if (htmldoc.MimeType.IndexOf("text") >= 0) {    // If we got 'text' data (not images)
                        string enc = "utf-8"; // default
                        if (webresponse.ContentEncoding != String.Empty) {
                            // Use the HttpHeader Content-Type in preference to the one set in META
                            htmldoc.Encoding = webresponse.ContentEncoding;
                        } else if (htmldoc.Encoding == String.Empty) {
                            // TODO: if still no encoding determined, try to readline the stream until we find either
                            // * META Content-Type or * </head> (ie. stop looking for META)
                            htmldoc.Encoding = enc; // default
                        }
                        //http://www.c-sharpcorner.com/Code/2003/Dec/ReadingWebPageSources.asp
                        System.IO.StreamReader stream = new System.IO.StreamReader
                                        (webresponse.GetResponseStream(), Encoding.GetEncoding(htmldoc.Encoding) );
    
                        htmldoc.Uri = webresponse.ResponseUri; // we *may* have been redirected... and we want the *final* URL
                        htmldoc.Length = webresponse.ContentLength;
                        htmldoc.All = stream.ReadToEnd ();
                        stream.Close();
                        success = true;
                    } else {
                        if (PrintDebug) Response.Write ("<br><font color=red>skipped mime type: "+htmldoc.MimeType+" for " + htmldoc.Uri + "</font>");
                    }
                    break;
            } // switch
            webresponse.Close();
        }
        return success;
    } // Download
    
    
    
    /// <summary>
    /// Extract information from a downloaded file (assumed to be HTML)
    /// and populate the passed-in HtmlDocument object's properties
    /// </summary>
    /// <remarks>
    /// "Original" link search Regex used by the code was from here
    /// http://www.dotnetjunkies.com/Tutorial/1B219C93-7702-4ADF-9106-DFFDF90914CF.dcik
    /// but it was not sophisticated enough to match all tag permutations
    ///
    /// whereas the Regex on this blog will parse ALL attributes from within tags...
    /// IMPORTANT when they're out of order, spaced out or over multiple lines
    /// http://blogs.worldnomads.com.au/matthewb/archive/2003/10/24/158.aspx
    /// http://blogs.worldnomads.com.au/matthewb/archive/2004/04/06/215.aspx
    ///
    /// http://www.experts-exchange.com/Programming/Programming_Languages/C_Sharp/Q_20848043.html
    /// </remarks>
    protected void Parse ( HtmlDocument htmldoc ) {
        string   htmlData = htmldoc.All;
        htmldoc.Html          = htmldoc.All;
        htmldoc.Title         = Regex.Match (htmlData, @"(?<=<title>).*?(?=</title>)",
                                    RegexOptions.IgnoreCase|RegexOptions.ExplicitCapture).Value;
    
        string metaKey = String.Empty, metaValue = String.Empty;
        foreach (Match metamatch in Regex.Matches (htmlData
                , @"<meta\s*(?:(?:\b(\w|-)+\b\s*(?:=\s*(?:""[^""]*""|'[^']*'|[^""'<> ]+)\s*)?)*)/?\s*>"
                , RegexOptions.IgnoreCase|RegexOptions.ExplicitCapture)) {
            metaKey = String.Empty;
            metaValue = String.Empty;
            // Loop through the attribute/value pairs inside the tag
            foreach (Match submetamatch in Regex.Matches(metamatch.Value.ToString()
                    , @"(?<name>\b(\w|-)+\b)\s*=\s*(""(?<value>[^""]*)""|'(?<value>[^']*)'|(?<value>[^""'<> ]+)\s*)+"
                    , RegexOptions.IgnoreCase|RegexOptions.ExplicitCapture)) {
    
                if ("http-equiv" == submetamatch.Groups[1].ToString().ToLower() ) {
                    metaKey = submetamatch.Groups[2].ToString();
                }
                if ( ("name" == submetamatch.Groups[1].ToString().ToLower() )
                    && (metaKey == String.Empty) ) { // if it's already set, HTTP-EQUIV takes precedence
                    metaKey = submetamatch.Groups[2].ToString();
                }
                if ("content" == submetamatch.Groups[1].ToString().ToLower() ) {
                    metaValue = submetamatch.Groups[2].ToString();
                }
            }
            switch (metaKey.ToLower()) {
                case "description":
                    htmldoc.Description = metaValue;
                    break;
                case "keywords":
                case "keyword":
                    htmldoc.Keywords = metaValue;
                    break;
                case "robots":
                case "robot":
                    htmldoc.SetRobotDirective (metaValue);
                    break;
            }
            if (PrintDebug) Response.Write(metaKey + " = " +  metaValue);
        }
    
        // vars used in link Regex loops
        string link=String.Empty;
        ArrayList linkLocal    = new ArrayList();
        ArrayList linkExternal = new ArrayList();
    
        // http://msdn.microsoft.com/library/en-us/script56/html/js56jsgrpregexpsyntax.asp
        // Original Regex, just found <a href=""> links; and was "broken" by spaces, out-of-order, etc
        // @"(?<=<a\s+href="").*?(?=""\s*/?>)"
        foreach (Match match in Regex.Matches(htmlData
                , @"(?<anchor><\s*(a|area)\s*(?:(?:\b\w+\b\s*(?:=\s*(?:""[^""]*""|'[^']*'|[^""'<> ]+)\s*)?)*)?\s*>)"
                , RegexOptions.IgnoreCase|RegexOptions.ExplicitCapture)) {
            // Parse ALL attributes from within tags... IMPORTANT when they're out of order!!
            // in addition to the 'href' attribute, there might also be 'alt', 'class', 'style', 'area', etc...
            // there might also be 'spaces' between the attributes and they may be ", ', or unquoted
            link=String.Empty;
            if (PrintDebug) Response.Write ("<br><font color=green>"+ Server.HtmlEncode(match.Value) + "</font>");
            foreach (Match submatch in Regex.Matches(match.Value.ToString()
                , @"(?<name>\b\w+\b)\s*=\s*(""(?<value>[^""]*)""|'(?<value>[^']*)'|(?<value>[^""'<> \s]+)\s*)+"
                , RegexOptions.IgnoreCase|RegexOptions.ExplicitCapture)) {
                // we're only interested in the href attribute (although in future maybe index the 'alt'/'title'?)
                if (PrintDebug) Response.Write ("<br><font color=green>" +submatch.Groups[1].ToString()  + "="+ submatch.Groups[2].ToString() + "</font>");
                if ("href" == submatch.Groups[1].ToString().ToLower() ) {
                    link = submatch.Groups[2].ToString();
                    break;
                }
            }
            // strip off internal links, so we don't index same page over again
            if (link.IndexOf("#") > -1) {
                link = link.Substring(0, link.IndexOf("#"));
            }
            if (link.IndexOf("javascript:") == -1
                && link.IndexOf("mailto:") == -1
                && !link.StartsWith("#")
                && link != String.Empty ) {
                if ( (link.Length > 8) && (link.StartsWith("http://")
                                            || link.StartsWith("https://")
                                            || link.StartsWith("file://")
                                            || link.StartsWith("//")
                                            || link.StartsWith(@"\\")) ) {
                    // all assumed to be 'external' links, which we don't process at all
                    // in this version, although we still populate the linkExternal array
                    // for possible future use.
                    linkExternal.Add (link) ;
                    if (PrintDebug) Response.Write (" X ");
                } else if (link.StartsWith("?")) {
                    // SPECIAL CASE:
                    // it's possible to have /?query which sends the querystring to the
                    // 'default' page in a directory
                    linkLocal.Add (htmldoc.Uri.AbsolutePath + link);
                    if (PrintDebug) Response.Write (" ? ");
                } else{
                    linkLocal.Add (link);
                    if (PrintDebug) Response.Write (" I ");
                }
            } // add each link to a collection
        } // foreach
        htmldoc.LocalLinks = linkLocal;
        htmldoc.ExternalLinks = linkExternal;
    } // Parse
    
    
    
    /// <summary>
    /// Remove HTML, convert to array, clean up words and index them
    /// </summary>
    /// <remarks>
    /// This function remains largely unchanged since Searcharoo Version 1
    /// </remarks>
    /// <return>Number of words catalogued</return>
    protected int Catalog (HtmlDocument htmldoc) {
        string filedesc="";
        long   filesize =0;
    
        string wordsOnly = StripHtml (htmldoc.All);
        /// ### VERBOSE ###
        if (PrintDebug) Response.Write ("<table><tr><td>" +wordsOnly + "</td></tr></table>");
    
        // ### If no META DESC, grab start of file text ###
        if (String.Empty == htmldoc.Description) {
            if (wordsOnly.Length > 350)
                filedesc = wordsOnly.Substring(0, 350);
            else
                filedesc = wordsOnly;
        } else { // use the Meta tag
            filedesc = htmldoc.Description;
        }
        // include the Keywords and Description from the Meta tags in the main text to be indexed
        wordsOnly = htmldoc.Keywords + " " + htmldoc.Description + " " + wordsOnly;
        // COMPRESS ALL WHITESPACE into a single space, seperating words
        Regex r = new Regex(@"\s+");            //remove all whitespace
        wordsOnly = r.Replace(wordsOnly, " ");
        string [] wordsOnlyA = wordsOnly.Split(' ');
    
        File infile = new File (htmldoc.Url
                            , htmldoc.Title
                            , filedesc
                            , DateTime.Now
                            , htmldoc.Length) ;
    
        // ### Loop through words in the file ###
        int i = 0;          // count of words
        string key = "";    // temp variables
        string val = "";
        string pos = "";
        // FUTURE: implement StringTokenizer class to replace Split() and allow enumeration
        // --> http://www.dotnet247.com/247reference/msgs/6/34077.aspx
        foreach (string word in wordsOnlyA) {
            key = word.Trim(' ', '?','\"', ',', '\'', ';', ':', '.', '(', ')').ToLower(); // this stuff is a bit 'English-language-centric'
            m_catalog.Add (key, infile, i);
            i++;
        } // foreach
    
        return i;
    }
    
    
    
    /// <summary>
    /// Storage for parsed HTML data returned by ParsedHtmlData();
    /// </summary>
    /// <remarks>
    /// We use this object to pass around information about HTML documents that
    /// are processed above. It encapsulates *some* functionality (Content-Type parsing
    /// and Robots directives) and will probably have more functions added to
    /// it over time.
    /// Potentially other classes might be added (PdfDocument) in which case it
    /// might make sense to have an IDocument interface or base class (and maybe
    /// a Factory to create them) to help the parser deal with different document
    /// types.
    /// </remarks>
    public class HtmlDocument {
    
        public HtmlDocument (Uri location) {
            m_Uri = location;
            Url = location.AbsoluteUri.ToString() ;
            LocalLinks = null;
            ExternalLinks = null;
        }
        private Uri m_Uri;
        private String m_contentType;
    
        /// <summary>http://www.ietf.org/rfc/rfc2396.txt</summary>
        public Uri    Uri {
            get {return m_Uri;}
            set {
                m_Uri = value;
                Url = value.AbsoluteUri.ToString() ;
            }
        }
        /// <summary>Raw content of page, as downloaded from the server</summary>
        public string All      = String.Empty;
        /// <summary>Encoding eg. "utf-8", "Shift_JIS", "iso-8859-1", "gb2312", etc</summary>
        public string Encoding = String.Empty;
        /// <summary>MimeType so we know whether to try and parse the contents, eg. "text/html", "text/plain", etc</summary>
        public string MimeType = String.Empty;
        public bool RobotIndexOK = true;
        public bool RobotFollowOK = true;
    
        public String ContentType {
            get {
                return m_contentType;
            }
            set {
                m_contentType = value.ToString();
                string[] contentTypeArray = m_contentType.Split(';');
                // Set MimeType if it's blank
                if (MimeType == String.Empty && contentTypeArray.Length>=1)
                    MimeType = contentTypeArray[0];
                // Set Encoding if it's blank
                if (Encoding == String.Empty && contentTypeArray.Length>=2) {
                    int charsetpos = contentTypeArray[1].IndexOf("charset");
                    if (charsetpos > 0) {
                        Encoding = contentTypeArray[1].Substring (charsetpos + 8, contentTypeArray[1].Length-charsetpos-8 );
                    }
                }
            }
        }
        /// <summary>Sort of obsolete with the Uri field being the main data to use</summary>
        public String Url;
        /// <summary>Html &lt;title&gt; tag</summary>
        public String Title         = String.Empty;
        /// <summary>Html &lt;meta http-equiv='description'&gt; tag</summary>
        public String Description   = String.Empty;
        /// <summary>Html &lt;meta http-equiv='keywords'&gt; tag</summary>
        public String Keywords      = String.Empty;
        /// <summary>Length as reported by the server in the Http headers</summary>
        public Int64 Length;
    
        public String Html;
    
        public ArrayList LocalLinks;
        public ArrayList ExternalLinks;
    
        /// <summary>
        /// Robots Exclusion Protocol
        /// http://www.robotstxt.org/wc/meta-user.html
        /// </summary>
        public void SetRobotDirective (string robotMetaContent) {
            robotMetaContent = robotMetaContent.ToLower();
            if (robotMetaContent.IndexOf("none") >= 0 ) {
                // 'none' means you can't Index or Follow!
                RobotIndexOK = false;
                RobotFollowOK = false;
            } else {
                if (robotMetaContent.IndexOf("noindex") >=0 ) {RobotIndexOK = false;}
                if (robotMetaContent.IndexOf("nofollow") >=0 ) {RobotFollowOK = false;}
            }
        }
    
        /// <summary>for debugging</summary>
        public override string ToString() {
            string linkstring = "";
            foreach (object link in LocalLinks) {
                linkstring += Convert.ToString (link) + "<br>";
            }
            return Title + " " + Description + " " + linkstring + "<hr>" + Html;
        }
    }
    
    
    
    
    
    /// <summary>
    /// Stripping HTML
    /// http://www.4guysfromrolla.com/webtech/042501-1.shtml
    ///
    /// Using regex to find tags without a trailing slash
    /// http://concepts.waetech.com/unclosed_tags/index.cfm
    ///
    /// http://msdn.microsoft.com/library/en-us/script56/html/js56jsgrpregexpsyntax.asp
    /// </summary>
    protected string StripHtml (string Html) {
    
        //Stripts the <script> tags from the Html
        string scriptregex = @"<scr" + @"ipt[^>.]*>[\s\S]*?</sc" + @"ript>";
        System.Text.RegularExpressions.Regex scripts = new System.Text.RegularExpressions.Regex(scriptregex , RegexOptions.IgnoreCase|RegexOptions.Multiline|RegexOptions.ExplicitCapture);
        string scriptless = scripts.Replace(Html, " ");
    
        //Stripts the <style> tags from the Html
        string styleregex = @"<style[^>.]*>[\s\S]*?</style>";
        System.Text.RegularExpressions.Regex styles = new System.Text.RegularExpressions.Regex(styleregex , RegexOptions.IgnoreCase|RegexOptions.Multiline|RegexOptions.ExplicitCapture);
        string styleless = styles.Replace (scriptless, " ");
    
        //Strips the HTML tags from the Html
        System.Text.RegularExpressions.Regex objRegExp = new System.Text.RegularExpressions.Regex("<(.|\n)+?>", RegexOptions.IgnoreCase);
    
        //Replace all HTML tag matches with the empty string
        string strOutput = objRegExp.Replace(styleless, " ");
    
        // Convert &&amp;amp;eacute; to &amp;eacute; (e') so French words are indexable
        // ## UNDOCUMENTED ## this line is new in Version 2, but was not documented
        // in the article... I may explain it when writing about Version 3...
        strOutput = ExtendedHtmlUtility.HtmlEntityDecode(strOutput, false);
        // The above line can be safely commented out on most English pages
        // since it's unlikely any 'important' characters would be HtmlEncoded
    
        //Replace all < and > with &lt; and &gt;
        strOutput = strOutput.Replace("<", "&lt;");
        strOutput = strOutput.Replace(">", "&gt;");
    
        objRegExp = null;
        return strOutput;
    }
    
    
    
    
    
    
    /*
    * (c) Craig Dunn - ConceptDevelopment.NET
    * 12-June-04
    *
    * To use:
    *    string encoded = ExtendedHtmlUtility.HtmlEntityEncode ("test string with Unicode chars and & < >");
    *    string decoded = ExtendedHtmlUtility.HtmlEntityDecode (encoded); // "string with &amp &lt; &gt;"
    *
    * More info:
    *    http://users.bigpond.com/conceptdevelopment/localization/htmlencode/
    */
    public class ExtendedHtmlUtility {
    
        /// <summary>
        /// Based on the 'reflected' code (from the Framework System.Web.HttpServerUtility)
        /// listed on this page
        /// UrlEncode vs. HtmlEncode
        /// http://www.aspnetresources.com/blog/encoding_forms.aspx
        ///
        /// PDF of unicode characters in the 0-127 (dec) range
        /// http://www.unicode.org/charts/PDF/U0000.pdf
        /// </summary>
        /// <param name="unicodeText"></param>
        /// <returns>
        /// &amp; becomes &amp;amp;  (encoded for XML Comments - don't be confused)
        /// 1-9a-zA-Z and some punctuation (ASCII, basically) remain unchanged
        /// </returns>
        public static string HtmlEntityEncode (string unicodeText) {
            return HtmlEntityEncode (unicodeText, true);
        }
    
        /// <param name="includeTagsEntities">whether to encode &amp; &lt; and &gt; which will
        /// cause the entire string to be 'displayable' as HTML. true is the default value.
        /// Setting this to false will result in a string where the non-ASCII characters
        /// are encoded, but HTML tags remain in-tact for display in a browser.</param>
        public static string HtmlEntityEncode (string unicodeText, bool includeTagsEntities) {
        int unicodeVal;
        string encoded=String.Empty;
        foreach (char c in unicodeText) {
            unicodeVal = c;
            switch (unicodeVal) {
                case '&':
                    if (includeTagsEntities) encoded += "&amp;";
                    break;
                case '<':
                    if (includeTagsEntities) encoded += "&lt;";
                    break;
                case '>':
                    if (includeTagsEntities) encoded += "&gt;";
                    break;
                default:
                    if ((c >= ' ') && (c <= 0x007E)) { // from 'space' to '~tilde' hex 20-7E (dec 32-127)
                        // in 'ascii' range x30 to x7a which is 0-9A-Za-z plus some punctuation
                        encoded += c;	// leave as-is
                    } else { // outside 'ascii' range - encode
                    encoded += string.Concat("&#",
                        unicodeVal.ToString(System.Globalization.NumberFormatInfo.InvariantInfo), ";");
                    }
                    break;
            }
        }
        return encoded;
        } // HtmlEntityEncode
    
    
        /// <summary>
        /// Converts Html Entities back to their 'underlying' Unicode characters
        /// </summary>
        /// <param name="encodedText"></param>
        /// <returns>
        /// &amp;amp; becomes &amp;  (encoded for XML Comments - don't be confused)
        /// 1-9a-zA-Z and some punctuation (ASCII, basically) remain unchanged
        /// </returns>
        public static string HtmlEntityDecode (string encodedText, bool includeTagsEntities) {
            return entityResolver.Replace (encodedText, new MatchEvaluator (ResolveEntity) );
        } // HtmlEntityDecode
    
        public static string HtmlEntityDecode (string encodedText) {
            return entityResolver.Replace (encodedText, new MatchEvaluator (ResolveEntity) );
        } // HtmlEntityDecode
    
        /// <summary>
        /// Static Regular Expression to match Html Entities in encoded text
        /// </summary>
        private static Regex entityResolver =
                                    new Regex (@"([&][#](?'unicode'\d+);)|([&](?'html'\w+);)");
    
    
    /// <summary>
    /// List of entities from here
    /// http://www.vigay.com/inet/acorn/browse-html2.html#entities
    /// </summary>
    private static string [,] entityLookupArray = {
    {"aacute", Convert.ToChar(0x00C1).ToString() }, {"aacute", Convert.ToChar(0x00E1).ToString() }, {"acirc", Convert.ToChar(0x00E2).ToString() }, {"acirc", Convert.ToChar(0x00C2).ToString() }, {"acute", Convert.ToChar(0x00B4).ToString() }, {"aelig", Convert.ToChar(0x00C6).ToString() }, {"aelig", Convert.ToChar(0x00E6).ToString() },
    {"agrave", Convert.ToChar(0x00C0).ToString() }, {"agrave", Convert.ToChar(0x00E0).ToString() }, {"alefsym", Convert.ToChar(0x2135).ToString() }, {"alpha", Convert.ToChar(0x0391).ToString() }, {"alpha", Convert.ToChar(0x03B1).ToString() }, {"amp", Convert.ToChar(0x0026).ToString() }, {"and", Convert.ToChar(0x2227).ToString() },
    {"ang", Convert.ToChar(0x2220).ToString() }, {"aring", Convert.ToChar(0x00E5).ToString() }, {"aring", Convert.ToChar(0x00C5).ToString() }, {"asymp", Convert.ToChar(0x2248).ToString() }, {"atilde", Convert.ToChar(0x00C3).ToString() }, {"atilde", Convert.ToChar(0x00E3).ToString() }, {"auml", Convert.ToChar(0x00E4).ToString() },
    {"auml", Convert.ToChar(0x00C4).ToString() }, {"bdquo", Convert.ToChar(0x201E).ToString() }, {"beta", Convert.ToChar(0x0392).ToString() }, {"beta", Convert.ToChar(0x03B2).ToString() }, {"brvbar", Convert.ToChar(0x00A6).ToString() }, {"bull", Convert.ToChar(0x2022).ToString() }, {"cap", Convert.ToChar(0x2229).ToString() }, {"ccedil", Convert.ToChar(0x00C7).ToString() },
    {"ccedil", Convert.ToChar(0x00E7).ToString() }, {"cedil", Convert.ToChar(0x00B8).ToString() }, {"cent", Convert.ToChar(0x00A2).ToString() }, {"chi", Convert.ToChar(0x03C7).ToString() }, {"chi", Convert.ToChar(0x03A7).ToString() }, {"circ", Convert.ToChar(0x02C6).ToString() }, {"clubs", Convert.ToChar(0x2663).ToString() }, {"cong", Convert.ToChar(0x2245).ToString() },
    {"copy", Convert.ToChar(0x00A9).ToString() }, {"crarr", Convert.ToChar(0x21B5).ToString() }, {"cup", Convert.ToChar(0x222A).ToString() }, {"curren", Convert.ToChar(0x00A4).ToString() }, {"dagger", Convert.ToChar(0x2020).ToString() }, {"dagger", Convert.ToChar(0x2021).ToString() }, {"darr", Convert.ToChar(0x2193).ToString() }, {"darr", Convert.ToChar(0x21D3).ToString() },
    {"deg", Convert.ToChar(0x00B0).ToString() }, {"delta", Convert.ToChar(0x0394).ToString() }, {"delta", Convert.ToChar(0x03B4).ToString() }, {"diams", Convert.ToChar(0x2666).ToString() }, {"divide", Convert.ToChar(0x00F7).ToString() }, {"eacute", Convert.ToChar(0x00E9).ToString() }, {"eacute", Convert.ToChar(0x00C9).ToString() }, {"ecirc", Convert.ToChar(0x00CA).ToString() },
    {"ecirc", Convert.ToChar(0x00EA).ToString() }, {"egrave", Convert.ToChar(0x00C8).ToString() }, {"egrave", Convert.ToChar(0x00E8).ToString() }, {"empty", Convert.ToChar(0x2205).ToString() }, {"emsp", Convert.ToChar(0x2003).ToString() }, {"ensp", Convert.ToChar(0x2002).ToString() }, {"epsilon", Convert.ToChar(0x03B5).ToString() }, {"epsilon", Convert.ToChar(0x0395).ToString() },
    {"equiv", Convert.ToChar(0x2261).ToString() }, {"eta", Convert.ToChar(0x0397).ToString() }, {"eta", Convert.ToChar(0x03B7).ToString() }, {"eth", Convert.ToChar(0x00F0).ToString() }, {"eth", Convert.ToChar(0x00D0).ToString() }, {"euml", Convert.ToChar(0x00CB).ToString() }, {"euml", Convert.ToChar(0x00EB).ToString() }, {"euro", Convert.ToChar(0x20AC).ToString() }, {"exist", Convert.ToChar(0x2203).ToString() },
    {"fnof", Convert.ToChar(0x0192).ToString() }, {"forall", Convert.ToChar(0x2200).ToString() }, {"frac12", Convert.ToChar(0x00BD).ToString() }, {"frac14", Convert.ToChar(0x00BC).ToString() }, {"frac34", Convert.ToChar(0x00BE).ToString() }, {"frasl", Convert.ToChar(0x2044).ToString() }, {"gamma", Convert.ToChar(0x03B3).ToString() }, {"gamma", Convert.ToChar(0x393).ToString() },
    {"ge", Convert.ToChar(0x2265).ToString() }, {"gt", Convert.ToChar(0x003E).ToString() }, {"harr", Convert.ToChar(0x21D4).ToString() }, {"harr", Convert.ToChar(0x2194).ToString() }, {"hearts", Convert.ToChar(0x2665).ToString() }, {"hellip", Convert.ToChar(0x2026).ToString() }, {"iacute", Convert.ToChar(0x00CD).ToString() }, {"iacute", Convert.ToChar(0x00ED).ToString() }, {"icirc", Convert.ToChar(0x00EE).ToString() },
    {"icirc", Convert.ToChar(0x00CE).ToString() }, {"iexcl", Convert.ToChar(0x00A1).ToString() }, {"igrave", Convert.ToChar(0x00CC).ToString() }, {"igrave", Convert.ToChar(0x00EC).ToString() }, {"image", Convert.ToChar(0x2111).ToString() }, {"infin", Convert.ToChar(0x221E).ToString() }, {"int", Convert.ToChar(0x222B).ToString() }, {"iota", Convert.ToChar(0x0399).ToString() },
    {"iota", Convert.ToChar(0x03B9).ToString() }, {"iquest", Convert.ToChar(0x00BF).ToString() }, {"isin", Convert.ToChar(0x2208).ToString() }, {"iuml", Convert.ToChar(0x00EF).ToString() }, {"iuml", Convert.ToChar(0x00CF).ToString() }, {"kappa", Convert.ToChar(0x03BA).ToString() }, {"kappa", Convert.ToChar(0x039A).ToString() }, {"lambda", Convert.ToChar(0x039B).ToString() },
    {"lambda", Convert.ToChar(0x03BB).ToString() }, {"lang", Convert.ToChar(0x2329).ToString() }, {"laquo", Convert.ToChar(0x00AB).ToString() }, {"larr", Convert.ToChar(0x2190).ToString() }, {"larr", Convert.ToChar(0x21D0).ToString() }, {"lceil", Convert.ToChar(0x2308).ToString() }, {"ldquo", Convert.ToChar(0x201C).ToString() }, {"le", Convert.ToChar(0x2264).ToString() },
    {"lfloor", Convert.ToChar(0x230A).ToString() }, {"lowast", Convert.ToChar(0x2217).ToString() }, {"loz", Convert.ToChar(0x25CA).ToString() }, {"lrm", Convert.ToChar(0x200E).ToString() }, {"lsaquo", Convert.ToChar(0x2039).ToString() }, {"lsquo", Convert.ToChar(0x2018).ToString() }, {"lt", Convert.ToChar(0x003C).ToString() }, {"macr", Convert.ToChar(0x00AF).ToString() },
    {"mdash", Convert.ToChar(0x2014).ToString() }, {"micro", Convert.ToChar(0x00B5).ToString() }, {"middot", Convert.ToChar(0x00B7).ToString() }, {"minus", Convert.ToChar(0x2212).ToString() }, {"mu", Convert.ToChar(0x039C).ToString() }, {"mu", Convert.ToChar(0x03BC).ToString() }, {"nabla", Convert.ToChar(0x2207).ToString() }, {"nbsp", Convert.ToChar(0x00A0).ToString() },
    {"ndash", Convert.ToChar(0x2013).ToString() }, {"ne", Convert.ToChar(0x2260).ToString() }, {"ni", Convert.ToChar(0x220B).ToString() }, {"not", Convert.ToChar(0x00AC).ToString() }, {"notin", Convert.ToChar(0x2209).ToString() }, {"nsub", Convert.ToChar(0x2284).ToString() }, {"ntilde", Convert.ToChar(0x00F1).ToString() }, {"ntilde", Convert.ToChar(0x00D1).ToString() }, {"nu", Convert.ToChar(0x039D).ToString() },
    {"nu", Convert.ToChar(0x03BD).ToString() }, {"oacute", Convert.ToChar(0x00F3).ToString() }, {"oacute", Convert.ToChar(0x00D3).ToString() }, {"ocirc", Convert.ToChar(0x00D4).ToString() }, {"ocirc", Convert.ToChar(0x00F4).ToString() }, {"oelig", Convert.ToChar(0x0152).ToString() }, {"oelig", Convert.ToChar(0x0153).ToString() }, {"ograve", Convert.ToChar(0x00F2).ToString() },
    {"ograve", Convert.ToChar(0x00D2).ToString() }, {"oline", Convert.ToChar(0x203E).ToString() }, {"omega", Convert.ToChar(0x03A9).ToString() }, {"omega", Convert.ToChar(0x03C9).ToString() }, {"omicron", Convert.ToChar(0x039F).ToString() }, {"omicron", Convert.ToChar(0x03BF).ToString() }, {"oplus", Convert.ToChar(0x2295).ToString() }, {"or", Convert.ToChar(0x2228).ToString() },
    {"ordf", Convert.ToChar(0x00AA).ToString() }, {"ordm", Convert.ToChar(0x00BA).ToString() }, {"oslash", Convert.ToChar(0x00D8).ToString() }, {"oslash", Convert.ToChar(0x00F8).ToString() }, {"otilde", Convert.ToChar(0x00F5).ToString() }, {"otilde", Convert.ToChar(0x00D5).ToString() }, {"otimes", Convert.ToChar(0x2297).ToString() }, {"ouml", Convert.ToChar(0x00D6).ToString() },
    {"ouml", Convert.ToChar(0x00F6).ToString() }, {"para", Convert.ToChar(0x00B6).ToString() }, {"part", Convert.ToChar(0x2202).ToString() }, {"permil", Convert.ToChar(0x2030).ToString() }, {"perp", Convert.ToChar(0x22A5).ToString() }, {"phi", Convert.ToChar(0x03A6).ToString() }, {"phi", Convert.ToChar(0x03C6).ToString() }, {"pi", Convert.ToChar(0x03A0).ToString() },
    {"pi", Convert.ToChar(0x03C0).ToString() }, {"piv", Convert.ToChar(0x03D6).ToString() }, {"plusmn", Convert.ToChar(0x00B1).ToString() }, {"pound", Convert.ToChar(0x00A3).ToString() }, {"prime", Convert.ToChar(0x2033).ToString() }, {"prime", Convert.ToChar(0x2032).ToString() }, {"prod", Convert.ToChar(0x220F).ToString() }, {"prop", Convert.ToChar(0x221D).ToString() },
    {"psi", Convert.ToChar(0x03C8).ToString() }, {"psi", Convert.ToChar(0x03A8).ToString() }, {"quot", Convert.ToChar(0x0022).ToString() }, {"radic", Convert.ToChar(0x221A).ToString() }, {"rang", Convert.ToChar(0x232A).ToString() }, {"raquo", Convert.ToChar(0x00BB).ToString() }, {"rarr", Convert.ToChar(0x2192).ToString() }, {"rarr", Convert.ToChar(0x21D2).ToString() }, {"rceil", Convert.ToChar(0x2309).ToString() },
    {"rdquo", Convert.ToChar(0x201D).ToString() }, {"real", Convert.ToChar(0x211C).ToString() }, {"reg", Convert.ToChar(0x00AE).ToString() }, {"rfloor", Convert.ToChar(0x230B).ToString() }, {"rho", Convert.ToChar(0x03C1).ToString() }, {"rho", Convert.ToChar(0x03A1).ToString() }, {"rlm", Convert.ToChar(0x200F).ToString() }, {"rsaquo", Convert.ToChar(0x203A).ToString() },
    {"rsquo", Convert.ToChar(0x2019).ToString() }, {"sbquo", Convert.ToChar(0x201A).ToString() }, {"scaron", Convert.ToChar(0x0160).ToString() }, {"scaron", Convert.ToChar(0x0161).ToString() }, {"sdot", Convert.ToChar(0x22C5).ToString() }, {"sect", Convert.ToChar(0x00A7).ToString() }, {"shy", Convert.ToChar(0x00AD).ToString() }, {"sigma", Convert.ToChar(0x03C3).ToString() },
    {"sigma", Convert.ToChar(0x03A3).ToString() }, {"sigmaf", Convert.ToChar(0x03C2).ToString() }, {"sim", Convert.ToChar(0x223C).ToString() }, {"spades", Convert.ToChar(0x2660).ToString() }, {"sub", Convert.ToChar(0x2282).ToString() }, {"sube", Convert.ToChar(0x2286).ToString() }, {"sum", Convert.ToChar(0x2211).ToString() }, {"sup", Convert.ToChar(0x2283).ToString() },
    {"sup1", Convert.ToChar(0x00B9).ToString() }, {"sup2", Convert.ToChar(0x00B2).ToString() }, {"sup3", Convert.ToChar(0x00B3).ToString() }, {"supe", Convert.ToChar(0x2287).ToString() }, {"szlig", Convert.ToChar(0x00DF).ToString() }, {"tau", Convert.ToChar(0x03A4).ToString() }, {"tau", Convert.ToChar(0x03C4).ToString() }, {"there4", Convert.ToChar(0x2234).ToString() },
    {"theta", Convert.ToChar(0x03B8).ToString() }, {"theta", Convert.ToChar(0x0398).ToString() }, {"thetasym", Convert.ToChar(0x03D1).ToString() }, {"thinsp", Convert.ToChar(0x2009).ToString() }, {"thorn", Convert.ToChar(0x00FE).ToString() }, {"thorn", Convert.ToChar(0x00DE).ToString() }, {"tilde", Convert.ToChar(0x02DC).ToString() }, {"times", Convert.ToChar(0x00D7).ToString() },
    {"trade", Convert.ToChar(0x2122).ToString() }, {"uacute", Convert.ToChar(0x00DA).ToString() }, {"uacute", Convert.ToChar(0x00FA).ToString() }, {"uarr", Convert.ToChar(0x2191).ToString() }, {"uarr", Convert.ToChar(0x21D1).ToString() }, {"ucirc", Convert.ToChar(0x00DB).ToString() }, {"ucirc", Convert.ToChar(0x00FB).ToString() }, {"ugrave", Convert.ToChar(0x00D9).ToString() },
    {"ugrave", Convert.ToChar(0x00F9).ToString() }, {"uml", Convert.ToChar(0x00A8).ToString() }, {"upsih", Convert.ToChar(0x03D2).ToString() }, {"upsilon", Convert.ToChar(0x03A5).ToString() }, {"upsilon", Convert.ToChar(0x03C5).ToString() }, {"uuml", Convert.ToChar(0x00DC).ToString() }, {"uuml", Convert.ToChar(0x00FC).ToString() }, {"weierp", Convert.ToChar(0x2118).ToString() },
    {"xi", Convert.ToChar(0x039E).ToString() }, {"xi", Convert.ToChar(0x03BE).ToString() }, {"yacute", Convert.ToChar(0x00FD).ToString() }, {"yacute", Convert.ToChar(0x00DD).ToString() }, {"yen", Convert.ToChar(0x00A5).ToString() }, {"yuml", Convert.ToChar(0x0178).ToString() }, {"yuml", Convert.ToChar(0x00FF).ToString() }, {"zeta", Convert.ToChar(0x03B6).ToString() }, {"zeta", Convert.ToChar(0x0396).ToString() },
    {"zwj", Convert.ToChar(0x200D).ToString() }, {"zwnj", Convert.ToChar(0x200C).ToString()}
    };
    
        private static StringDictionary m_EntityLookup;
        protected static StringDictionary EntityLookup {
            get {
                m_EntityLookup = new StringDictionary ();
                if (null == m_EntityLookup) {
                    for (int i = 0; i < entityLookupArray.Length; i++) {
                        m_EntityLookup.Add (entityLookupArray[i,0],entityLookupArray[i,1]);
                    }
                }
                return m_EntityLookup;
            }
        }
    
        /// <summary>
        /// Regex Match processing delegate to replace the Entities with their
        /// underlying Unicode character.
        /// </summary>
        /// <param name="matchToProcess">Regular Expression Match</param>
        /// <returns>
        /// &amp;amp; becomes &amp;  (encoded for XML Comments - don't be confused)
        /// and &amp;eacute; becomes é
        /// </returns>
        private static string ResolveEntity (System.Text.RegularExpressions.Match matchToProcess) {
    
        // ## HARDCODED ##
        bool includeTagsEntities = false;
    
        string x = ""; // default 'char placeholder' if cannot be resolved - shouldn't occur
        if (matchToProcess.Groups["unicode"].Success) {
            x = Convert.ToChar(Convert.ToInt32(matchToProcess.Groups["unicode"].Value) ).ToString();
        } else {
            if (matchToProcess.Groups["html"].Success) {
                string entity = matchToProcess.Groups["html"].Value.ToLower();
                switch (entity) {
                    case "lt":
                    case "gt":
                    case "amp":
                        if (includeTagsEntities)
                            x = EntityLookup[matchToProcess.Groups["html"].Value.ToLower()];
                        else
                            x = "&" + entity + ";";
                        break;
                    default:
                        x = EntityLookup[matchToProcess.Groups["html"].Value.ToLower()];
                        break;
                }
            }
        }
        return x;
        } // ResolveEntity()
    } // class ExtendedHtmlUtility
    
    
    
    
    // FUTURE:
    //
    // Use to save ZIP download
    // http://www.123aspx.com/redir.aspx?res=31602
    //
    // Proxy
    // http://www.experts-exchange.com/Programming/Programming_Languages/Dot_Net/Q_20974147.html
    // http://msdn.microsoft.com/library/en-us/cpref/html/frlrfsystemnetglobalproxyselectionclasstopic.asp

</script>
