#!/bin/bash
pp -l /usr/local/lib/libMagickCore-Q16.so.7.0.0 -l /usr/lib/libtiff.so.4 -l /usr/lib/libtiff.so.4.2.1 -l /usr/lib/libjpeg.so.62 -l /usr/lib/libjpeg.so.62.0.0 -l /usr/local/lib/libMagickCore-Q16.so.7 -l /usr/lib/libgdbm.so.3 -l /usr/lib/libgdbm.so.3.0.0 -M MARC::Charset::Table -M MARC::Charset -M MARC::File::SAX -M MARC::File::XML -M XML::SAX::PurePerl -o uploadZB-v13 uploadZB.pl
