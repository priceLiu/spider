using System;
using System.IO;
using System.Xml.Serialization;
using System.Collections.Specialized;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections;

//
// http://www.dotnetbips.com/displayarticle.aspx?id=43f
// http://www.microbion.co.uk/developers/csharp/dirlist.htm

// Stripping HTML
// http://www.4guysfromrolla.com/webtech/042501-1.shtml

// Opening a file from ASP.NET
// http://aspnet.4guysfromrolla.com/articles/051802-1.aspx

// Practical parsing in Regular Expressions
// http://weblogs.asp.net/rosherove/articles/6946.aspx
namespace Searcharoo.Net {

    /// <summary>Catalog of words and pages<summary>
	public class Catalog {
		/// <summary>Internal datastore of Words referencing Files</summary>
		private System.Collections.Hashtable index;	//TODO: implement collection with faster searching

		public int Length {
		  get {return index.Count;}
		}
		/// <summary>Constructor</summary>
		public Catalog () {
			index = new System.Collections.Hashtable ();
		}
		/// <summary>Add a new Word/File pair to the Catalog</summary>
		public bool Add (string word, File infile, int position){
            // ### Make sure the Word object is in the index ONCE only
			if (index.ContainsKey (word) ) {
				Word theword = (Word)index[word];	// add this file reference to the Word
				theword.Add(infile, position);
			} else {
				Word theword = new Word(word, infile, position);	// create a new Word object
				index.Add(word, theword);
			}
			return true;
		}
        /// <summary>Returns all the Files which contain the searchWord</summary>
        /// <returns>Hashtable </returns>
        public Hashtable Search (string searchWord) {
            // apply the same 'trim' as when we're building the catalog
            searchWord = searchWord.Trim('?','\"', ',', '\'', ';', ':', '.', '(', ')').ToLower();
            Hashtable retval = null;
            if (index.ContainsKey (searchWord) ) { // does all the work !!!
                Word thematch = (Word)index[searchWord];
                retval = thematch.InFiles(); // return the collection of File objects
            }
            return retval;
        }
		/// <summary>Debug string</summary>
		public override string ToString() {
			string wordlist="";
			//foreach (object w in index.Keys) temp += ((Word)w).ToString();	// output ALL words, will take a long time
			return "\nCATALOG :: " + index.Values.Count.ToString() + " words.\n" + wordlist;
		}
	}

    /// <summary>Instance of a word<summary>
    public class Word {
        /// <summary>The cataloged word</summary>
        public string Text;
		/// <summary>Collection of files the word appears in</summary>
		private System.Collections.Hashtable fileCollection = new System.Collections.Hashtable ();
		/// <summary>Constructor with first file reference</summary>
		public Word (string text, File infile, int position) {
			Text = text;
			//WordInFile thefile = new WordInFile(filename, position);
			fileCollection.Add (infile, 1);
		}
		/// <summary>Add a file referencing this word</summary>
		public void Add (File infile, int position) {
			if (fileCollection.ContainsKey (infile)) {
				int wordcount = (int)fileCollection[infile];
				fileCollection[infile] = wordcount + 1 ; //thefile.Add (position);
			} else {
				//WordInFile thefile = new WordInFile(filename, position);
				fileCollection.Add (infile, 1);
			}
		}
		/// <summary>Collection of files containing this Word (Value=WordCount)</summary>
		public Hashtable InFiles () {
		  return fileCollection;
		}
		/// <summary>Debug string</summary>
		public override string ToString() {
			string temp="";
			foreach (object tempFile in fileCollection.Values) temp += ((File)tempFile).ToString();
			return "\tWORD :: " + Text + "\n\t\t" + temp + "\n";
		}
	}


	/// <summary>File attributes</summary>
	/// <remarks>Beware ambiguity with System.IO.File - always fully qualify File object references</remarks>
    public class File {
        public string Url;
        public string Title;
        public string Description;
        public DateTime CrawledDate;
        public long   Size;

        /// <summary>Constructor requires all File attributes</summary>
        public File (string url, string title, string description, DateTime datecrawl, long length) {
			Title       = title;
			Description = description;
			CrawledDate = datecrawl;
			Url         = url;
			Size        = length;
        }
        /// <summary>Debug string</summary>
		public override string ToString() {
			return "\tFILE :: " + Url + " -- " + Title + " - " + Size + " bytes + \n\t" + Description + "\n";
		}
    } // File

} // namespace Searcharoo.Net
