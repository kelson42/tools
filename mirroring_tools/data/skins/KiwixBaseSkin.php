<?php
class KiwixBaseSkin extends SkinTemplate {
	/** Using kiwix. */
	function initPage( OutputPage $out ) {
		parent::initPage( $out );
		$this->skinname  = 'KiwixBaseSkin';
		$this->stylename = 'KiwixBaseSkin';
		$this->template  = 'KiwixBaseSkin';

	}

	function setupSkinUserCss( OutputPage $out ) {
		global $wgHandheldStyle;

		parent::setupSkinUserCss( $out );

		// Append to the default screen common & print styles...
		$out->addStyle( 'monobook/main.css', 'screen' );
		if( $wgHandheldStyle ) {
			// Currently in testing... try 'chick/main.css'
			$out->addStyle( $wgHandheldStyle, 'handheld' );
		}

		$out->addStyle( 'monobook/IE50Fixes.css', 'screen', 'lt IE 5.5000' );
		$out->addStyle( 'monobook/IE55Fixes.css', 'screen', 'IE 5.5000' );
		$out->addStyle( 'monobook/IE60Fixes.css', 'screen', 'IE 6' );
		$out->addStyle( 'monobook/IE70Fixes.css', 'screen', 'IE 7' );

		$out->addStyle( 'monobook/rtl.css', 'screen', '', 'rtl' );
	}

	// responsible for avoiding the red links
	function makeBrokenLinkObj( &$nt, $text = '', $query = '', $trail = '', $prefix = '' ) {
		if ( !isset( $nt ) ) {
			return "";
		}

		// return empty string if it a template inclusion/link
		if ( $nt->getNamespace() == NS_TEMPLATE ) {
		         return "";    
		}

		if ( $nt->getNamespace() == NS_CATEGORY ) {
			# Determine if the category has any articles in it
			$dbr = wfGetDB( DB_SLAVE );
			$hasMembers = $dbr->selectField( 'categorylinks', '1', 
				array( 'cl_to' => $nt->getDBkey() ), __METHOD__ );
			if ( $hasMembers ) {
				return $this->makeKnownLinkObj( $nt, $text, $query, $trail, $prefix );
			}
		}

		if ( $text == '' ) {
			$text = $nt->getPrefixedText();
		}
		return $prefix . $text . $trail;
	}

	// reponsible to avoid media links
	function makeMediaLinkObj( $title, $text = '', $time = false ) {
	  return $text;
	}

	// responsible for removing failing pictures
	function makeImageLink2( Title $title, $file, $frameParams = array(), $handlerParams = array(), $time = false, $query = "" ) {
                if (!$file || !$file->exists()) {
                   return "";
		}

		$html = Linker::makeImageLink2($title, $file, $frameParams, $handlerParams, $time, $query);

		// remove image links, the test is a trick to avoid doing that for imagemap pictures
		$trace=debug_backtrace();
		$caller=$trace[2];

		if ($caller['class'] == 'Parser') {
		  preg_match_all('/<a [^>]*>(.*?<img.*?)<\/a>/s', $html, $matches);
		  if (count($matches)) {
		    $html = str_replace($matches[0], $matches[1], $html);
		  }
		}

		return $html;
        }

	// remove zoomicon in thumbs
	function makeThumbLink2( Title $title, $file, $frameParams = array(), $handlerParams = array(), $time = false, $query = "" ) {
	        $html = Linker::makeThumbLink2($title, $file, $frameParams, $handlerParams, $time, $query );

		// remove zoomicon
		preg_match_all('/<div class="magnify">.*?<\/div>/s', $html, $matches);
		foreach ($matches[0] as $match) {
		  $html = str_replace($match, "", $html);
		}
		
		return $html;
	}

	// rewrite finale html output
	function outputPage( OutputPage $out )  {
		 $content = $out->mBodytext;

		 // remove links to disemb. and other (if no link inside)
		 preg_match_all('/<dd>.*?<\/dd>|<div class="dablink">.*?<\/div>/s', $content, $matches);
		 foreach ($matches[0] as $match) {
		 	 if (!preg_match("/.*?<a.*?/s", $match)) {
			    $content = str_replace($match, "", $content);
			 } 
		 }
		 
		 // remove return cariage after (sub-)title
		 $content = str_replace("<p><br />", "<p>", $content);
		 
		 // remove empty paragraph
		 $content = str_replace("<p><br /></p>", "", $content);

		 $out->mBodytext = $content;
		 SkinTemplate::outputPage($out);
	}
}
