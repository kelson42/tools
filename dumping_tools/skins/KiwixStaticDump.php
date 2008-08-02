<?php

/**
 * Default skin for HTML dumps, based on MonoBook.php
 */

if( !defined( 'MEDIAWIKI' ) )
	die( -1 );

/** */
require_once( 'includes/SkinTemplate.php' );

/**
 * Inherit main code from SkinTemplate, set the CSS and template filter.
 * @todo document
 * @package MediaWiki
 * @subpackage Skins
 */
class SkinKiwixStaticDump extends SkinTemplate {
	/** Using monobook. */
	function initPage( &$out ) {
		SkinTemplate::initPage( $out );
       	        $this->skinname  = 'monobook';
                $this->stylename = 'monobook';
		$this->template  = 'KiwixStaticDumpTemplate';
	}

	function buildSidebar() {
		$sections = parent::buildSidebar();
		$badMessages = array( 'recentchanges-url', 'randompage-url' );
		$badUrls = array();
		foreach ( $badMessages as $msg ) {
			$badUrls[] = self::makeInternalOrExternalUrl( wfMsgForContent( $msg ) );
		}

		foreach ( $sections as $heading => $section ) {
			foreach ( $section as $index => $link ) {
				if ( in_array( $link['href'], $badUrls ) ) {
					unset( $sections[$heading][$index] );
				}
			}
		}
		return $sections;
	}

	function buildContentActionUrls() {
		global $wgKiwixStaticDump;

		$content_actions = array();
		$nskey = $this->getNameSpaceKey();

		if ( isset( $wgKiwixStaticDump ) ) {
			$content_actions['current'] = array(
				'text' => wfMsg( 'currentrev' ),
				'href' => str_replace( '$1', wfUrlencode( $this->mTitle->getPrefixedDBkey() ),
					$wgKiwixStaticDump->oldArticlePath ),
				'class' => false
			);
		}
		return $content_actions;
	}

	function makeBrokenLinkObj( &$nt, $text = '', $query = '', $trail = '', $prefix = '' ) {
		if ( !isset( $nt ) ) {
			return "<!-- ERROR -->{$prefix}{$text}{$trail}";
		}

		if ( $nt->getNamespace() == 10 ) {
			return "";
		}

		if ( $nt->getNamespace() == NS_CATEGORY ) {
			# Determine if the category has any articles in it
			$dbr =& wfGetDB( DB_SLAVE );
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

        function makeImageLink2( Title $title, $file, $frameParams = array(), $handlerParams = array() ) {
                global $wgContLang, $wgUser, $wgThumbLimits, $wgThumbUpright;
                if ( $file && !$file->allowInlineDisplay() ) {
                        wfDebug( __METHOD__.': '.$title->getPrefixedDBkey()." does not allow inline display\n" );
                        return $this->makeKnownLinkObj( $title );
                }

                // Shortcuts
                $fp =& $frameParams;
                $hp =& $handlerParams;

                // Clean up parameters
                $page = isset( $hp['page'] ) ? $hp['page'] : false;
                if ( !isset( $fp['align'] ) ) $fp['align'] = '';
                if ( !isset( $fp['alt'] ) ) $fp['alt'] = '';

                $prefix = $postfix = '';

                if ( 'center' == $fp['align'] )
                {
                        $prefix  = '<div class="center">';
                        $postfix = '</div>';
                        $fp['align']   = 'none';
                }
                if ( $file && !isset( $hp['width'] ) ) {
                        $hp['width'] = $file->getWidth( $page );

                        if( isset( $fp['thumbnail'] ) || isset( $fp['framed'] ) || isset( $fp['frameless'] ) || !$hp['width'] ) {
                                $wopt = $wgUser->getOption( 'thumbsize' );

                                if( !isset( $wgThumbLimits[$wopt] ) ) {
                                         $wopt = User::getDefaultOption( 'thumbsize' );
                                }

                                // Reduce width for upright images when parameter 'upright' is used
                                if ( isset( $fp['upright'] ) && $fp['upright'] == 0 ) {
                                        $fp['upright'] = $wgThumbUpright;
                                }
                                // Use width which is smaller: real image width or user preference width
                                // For caching health: If width scaled down due to upright parameter, round to full __0 pixel to avoid theof odd thumbs
                                $prefWidth = isset( $fp['upright'] ) ?
                                        round( $wgThumbLimits[$wopt] * $fp['upright'], -1 ) :
                                        $wgThumbLimits[$wopt];
                                if ( $hp['width'] <= 0 || $prefWidth < $hp['width'] ) {
                                        $hp['width'] = $prefWidth;
                                }
                        }
                }

                if ( isset( $fp['thumbnail'] ) || isset( $fp['manualthumb'] ) || isset( $fp['framed'] ) ) {

                        # Create a thumbnail. Alignment depends on language
                        # writing direction, # right aligned for left-to-right-
                        # languages ("Western languages"), left-aligned
                        # for right-to-left-languages ("Semitic languages")
                        #
                        # If  thumbnail width has not been provided, it is set
                        # to the default user option as specified in Language*.php
                        if ( $fp['align'] == '' ) {
                                $fp['align'] = $wgContLang->isRTL() ? 'left' : 'right';
                        }
                        return $prefix.$this->makeThumbLink2( $title, $file, $fp, $hp ).$postfix;
                }

	       if ( $file && $hp['width'] ) {
                        # Create a resized image, without the additional thumbnail features
                        $thumb = $file->transform( $hp );
                } else {
                        $thumb = false;
                }

                if ( !$thumb ) {
                        $s = $this->makeBrokenImageLinkObj( $title );
                } else {
			$path = $thumb->file->path;

                        $bitmap = true;
                        if (strstr(strtolower($path), "svg")) {
                                $bitmap = false;
                        } else {
				// $thumb->url = $thumb->file->getURL();
			}

                        $s .= $thumb->toHtml( array(
                                'alt' => $fp['alt'],
                                'img-class' => 'image', //kelson
                                'file-link' => $bitmap, //kelson
                                 ) );


                        if ($bitmap) {
                     	   $s = str_replace("href=", "title=\"".$fp['alt']."\" rel=\"lightbox\" href=", $s); //kelson
                        }
                }
                if ( '' != $fp['align'] ) {
                        $s = "<div class=\"float{$fp['align']}\"><span>{$s}</span></div>";
                }

                return str_replace("\n", ' ',$prefix.$s.$postfix);
        }

        function makeThumbLink2( Title $title, $file, $frameParams = array(), $handlerParams = array() ) {
                global $wgStylePath, $wgContLang;
                $exists = $file && $file->exists();

                # Shortcuts
                $fp =& $frameParams;
                $hp =& $handlerParams;

                $page = isset( $hp['page'] ) ? $hp['page'] : false;
                if ( !isset( $fp['align'] ) ) $fp['align'] = 'right';
                if ( !isset( $fp['alt'] ) ) $fp['alt'] = '';
                if ( !isset( $fp['caption'] ) ) $fp['caption'] = '';

                if ( empty( $hp['width'] ) ) {
                        // Reduce width for upright images when parameter 'upright' is used
                        $hp['width'] = isset( $fp['upright'] ) ? 130 : 180;
                }
                $thumb = false;

                if ( !$exists ) {
                        $outerWidth = $hp['width'] + 2;
                } else {
                        if ( isset( $fp['manualthumb'] ) ) {
                                # Use manually specified thumbnail
                                $manual_title = Title::makeTitleSafe( NS_IMAGE, $fp['manualthumb'] );
                                if( $manual_title ) {
                                        $manual_img = wfFindFile( $manual_title );
                                        if ( $manual_img ) {
                                                $thumb = $manual_img->getUnscaledThumb();
                                        } else {
                                                $exists = false;
                                        }
                                }
                        } elseif ( isset( $fp['framed'] ) ) {
                                // Use image dimensions, don't scale
                                $thumb = $file->getUnscaledThumb( $page );
                        } else {
                                # Do not present an image bigger than the source, for bitmap-style images
                                # This is a hack to maintain compatibility with arbitrary pre-1.10 behaviour
                                $srcWidth = $file->getWidth( $page );
                                if ( $srcWidth && !$file->mustRender() && $hp['width'] > $srcWidth ) {
                                        $hp['width'] = $srcWidth;
                                }
                                $thumb = $file->transform( $hp );
                        }

                        if ( $thumb ) {
                                $outerWidth = $thumb->getWidth() + 2;
                        } else {
                                $outerWidth = $hp['width'] + 2;
                        }
                }


             $query = $page ? 'page=' . urlencode( $page ) : '';
                $url = $title->getLocalURL( $query );

                $more = htmlspecialchars( wfMsg( 'thumbnail-more' ) );
                $magnifyalign = $wgContLang->isRTL() ? 'left' : 'right';
                $textalign = $wgContLang->isRTL() ? ' style="text-align:right"' : '';

                $s = "<div class=\"thumb t{$fp['align']}\"><div class=\"thumbinner\" style=\"width:{$outerWidth}px;\">";
                if( !$exists ) {
                        $s .= $this->makeBrokenImageLinkObj( $title );
                        $zoomicon = '';
                } elseif ( !$thumb ) {
                        $s .= htmlspecialchars( wfMsg( 'thumbnail_error', '' ) );
                        $zoomicon = '';
                } else {

			$path = $thumb->file->path;
			$bitmap = true;
			if (strstr(strtolower($path), "svg")) {
				$bitmap = false;
			} else {
                                // $thumb->url = $thumb->file->getURL();
                        }

                        $s .= $thumb->toHtml( array(
                                'alt' => $fp['alt'],
                                'img-class' => 'thumbimage', //kelson
				'file-link' =>  $bitmap, //kelson
                                 ) );
			
			if ($bitmap) {
			$s = str_replace("href=", "title=\"".$fp['alt']."\" rel=\"lightbox\" href=", $s); //kelson
			}

			/*
                        if ( isset( $fp['framed'] ) ) {
                                $zoomicon="";
                        } else {
                                $zoomicon =  '<div class="magnify" style="float:'.$magnifyalign.'">'.
                                        '<a href="'.$url.'" rel="lightbox" class="internal" title="'.$more.'">'.
                                        '<img src="'.$wgStylePath.'/common/images/magnify-clip.png" ' .
                                        'width="15" height="11" alt="" /></a></div>';
                        }
			*/
                }
                $s .= '  <div class="thumbcaption"'.$textalign.'>'.$zoomicon.$fp['caption']."</div></div></div>";
                return str_replace("\n", ' ', $s);
        }



}

/**
 * @todo document
 * @package MediaWiki
 * @subpackage Skins
 */
class KiwixStaticDumpTemplate extends QuickTemplate {
	/**
	 * Template filter callback for MonoBook skin.
	 * Takes an associative array of data set from a SkinTemplate-based
	 * class, and a wrapper for MediaWiki's localization database, and
	 * outputs a formatted page.
	 *
	 * @access private
	 */

	function execute() {
		wfSuppressWarnings();
?><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="<?php $this->text('lang') ?>" lang="<?php $this->text('lang') ?>" dir="<?php $this->text('dir') ?>">
  <head>
    <meta http-equiv="Content-Type" content="<?php $this->text('mimetype') ?>; charset=<?php $this->text('charset') ?>" />
    <title><?php $title = htmlspecialchars( $this->data['pagetitle'] ); $offset = strpos($title, " - "); echo substr($title, 0, $offset); ?></title>
    
    <link rel="stylesheet" type="text/css" href="/skins/tmp/shared.css" />
    <link rel="stylesheet" type="text/css" href="/skins/tmp/main.css" />
    <link rel="stylesheet" type="text/css" media="print" href="/skins/tmp/commonPrint.css" />
    <link rel="stylesheet" type="text/css" href="/skins/tmp/common.css" />
    <link rel="stylesheet" type="text/css" href="/skins/tmp/monobook.css" />
    <link rel="stylesheet" type="text/css" href="/skins/tmp/gen.css" />

    <script type="text/javascript" src="/skins/tmp/wikibits.js"></script>
    <script type="text/javascript" src="/skins/tmp/ajax.js"></script>
    <script type="text/javascript" src="/skins/tmp/ajaxwatch.js"></script>
    <script type="text/javascript" src="/skins/tmp/gen.js"></script>

    <script type="text/javascript" src="/skins/lightbox/js/prototype.js"></script>
    <script type="text/javascript" src="/skins/lightbox/js/scriptaculous.js"></script>
    <script type="text/javascript" src="/skins/lightbox/js/lightbox.js"></script>
    <script type="text/javascript" src="/skins/lightbox/js/effects.js"></script>
    <link rel="stylesheet" href="/skins/lightbox/css/lightbox.css" type="text/css" media="screen" />

  </head>
  <body style="padding: 0 1em 1em 1em; font-size: 14px;">
      <a name="top" id="contentTop"></a>
      <h1 class="firstHeading"><?php $this->data['displaytitle']!=""?$this->html('title'):$this->text('title') ?></h1>
	  <div id="bodyContent">
	    <div id="contentSub"><?php $this->html('subtitle') ?></div>
	    <?php if($this->data['undelete']) { ?><div id="contentSub"><?php     $this->html('undelete') ?></div><?php } ?>
	    <?php if($this->data['newtalk'] ) { ?><div class="usermessage"><?php $this->html('newtalk')  ?></div><?php } ?>
	    <?php 
		$html = $this->data['bodytext'];
		$html = str_replace("<p><br /></p>", "", $html );
		$html = str_replace("<p><br />", "<p>", $html );
		echo $html;
            ?>
	  </div>
  </body>
</html>
<?php
		wfRestoreWarnings();
	}
}
?>
