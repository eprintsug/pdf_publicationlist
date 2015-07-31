=head1 NAME

EPrints::Plugin::Export::UserPDF

=cut

package EPrints::Plugin::Export::UserPDF;

use PDF::API2;
use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

use constant mm => 25.4 / 72;
use constant pt => 1;


sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "PDF";
	$self->{accept} = [ 'list/user', 'dataobj/user' ];
	$self->{visible} = "all";
	$self->{suffix} = ".pdf";
	$self->{mimetype} = "application/pdf; charset=utf-8";
	$self->{arguments}->{hide_volatile} = 1;

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $repo = $plugin->{repository};
        my $pdf_settings = $repo->config("profile_pdf_settings");;
        my $userpath = $dataobj->_userid_to_path();
        my $pdf_path = $repo->config("archiveroot")."/meprints/$userpath/profile";

	unless ( -e $pdf_path )
	{
		my $created = EPrints::Platform::mkdir( $pdf_path );
	}
	my $pdf_filename = $plugin->form_filename( $dataobj );
        $pdf_path .= "/".$pdf_filename;
        my $pdf = $plugin->create_pdf( $pdf_path, $dataobj, $pdf_settings );

        EPrints::Apache::AnApache::header_out(
                        $repo->get_request,
                        "Content-Disposition: inline; filename=".$pdf_filename.";",
                        );

	open(PDF, $pdf) or die("can't open file");

	binmode PDF;
	my $output = do { local $/; <PDF> };
	close(PDF);

	return $output;
}

sub form_filename
{
	my( $plugin, $user ) = @_;

        my $repo = $plugin->{repository};
        my $pdf_settings = $repo->config("profile_pdf_settings");;
	my $pdf_filename = "";
	$pdf_filename .= $pdf_settings->{filename_prefix};
	my $user_name = $user->get_value( "name" );
	if ( $user_name && $pdf_settings->{filename_inc_name} )
	{
		$pdf_filename .= $user_name->{given} if $user_name->{given};
		$pdf_filename .= "_" if $user_name->{given};
		$pdf_filename .= $user_name->{family} if $user_name->{family};
	}
	$pdf_filename .= ".".$pdf_settings->{filename_ext};
	return $pdf_filename;
}

sub create_pdf
{
        my ( $plugin, $pdf_file, $user, $settings ) = @_;

        my $repo = $plugin->repository;
        my $date_now = $plugin->get_date_now;

        if ( -e $pdf_file && $settings->{cache_pdf} )
	{
                my $timestampfile = $repo->config( "variables_path" )."/meprints.timestamp";
                my $need_to_update = 0;
                if( -e $timestampfile )
                {
                        my $poketime = (stat( $timestampfile ))[9];
                        my $targettime = (stat( $pdf_file ))[9];
                        if( $targettime < $poketime ) { $need_to_update = 1; }
                }
		return $pdf_file unless $need_to_update;
	}

        # File was not found so we need to create it
        my $pdf = PDF::API2->new( -file => $pdf_file );

	my $publications = $user->owned_eprints_list();
	my $pub_text = {};
	my $order = 0;

	my $citation_style = "default";
	# uncomment if you allow users to set their preferred citation style
	#$citation_style = lc($user->get_value( "cite_default")) if $user->is_set( "cite_default");

	$publications->map( sub {
		my( $repo, $dataset, $eprint ) = @_;
		my $type = $eprint->get_value( "type" );
		my $id = $eprint->get_value( "eprintid" );
		$order++;
		my $category = "general";
		$category = $settings->{category}->{$type} if $settings->{category}->{$type};
		if ( $category eq "article" )
		{
			$pub_text->{articles}->{$order}->{$id} = EPrints::Utils::tree_to_utf8( $eprint->render_citation( $citation_style ) );
		}
		elsif ( $category eq "book" )
		{
			$pub_text->{books}->{$order}->{$id} = EPrints::Utils::tree_to_utf8( $eprint->render_citation( $citation_style ) );
		}
		else
		{
			$pub_text->{general}->{$order}->{$id} = EPrints::Utils::tree_to_utf8( $eprint->render_citation( $citation_style ) );
		}
	});

	my $fonts = {
                header => $pdf->corefont( $settings->{header_font_name}, -encoding => 'utf-8' ),
                title  => $pdf->corefont( $settings->{title_font_name}, -encoding => 'utf-8' ),
                sub_title  => $pdf->corefont( $settings->{sub_title_font_name}, -encoding => 'utf-8' ),
                watermark  => $pdf->corefont( $settings->{watermark_font_name}, -encoding => 'utf-8' ),
                detail => $pdf->corefont( $settings->{font_name}, -encoding => 'utf-8' ),
		footer => $pdf->corefont( $settings->{footer_font_name}, -encoding => 'utf-8' ,)
	};

	my $page_number = 1;
	my ($page, $x, $y) = $plugin->add_page( $pdf, $settings, $fonts, $user, 1, $page_number );
	foreach my $cat ( qw/ articles books general / )
	{
		my $first = 1;
		my $continuation = 0;
		#foreach my $id ( keys %{$pub_text->{$cat}} )
		foreach my $order ( sort { $a <=> $b } keys %{$pub_text->{$cat}} )
		{
			my $id = (keys %{$pub_text->{$cat}->{$order}})[0];
			my $leftover = "";
			if ( $y < 56 )
			{
				# not much room left so start a new page
				$continuation = $first ? 0 : 1;
				$first = 1;
				$page_number++;
				($page, $x, $y) = $plugin->add_page( $pdf, $settings, $fonts, $user, 0, $page_number ) if $y < 56; 
			}
        		($page, $y, $leftover) = $plugin->write_profile_pubs($pdf, $page, $user, $settings, $fonts, 
							$x, $y, $id, $pub_text->{$cat}->{$order}->{$id}, $cat, $first, $continuation );
			$first = 0;
			$continuation = 0;
			while ( $leftover )
			{
				$page_number++;
				($page, $x, $y) = $plugin->add_page( $pdf, $settings, $fonts, $user, 0, $page_number );
				($page, $y, $leftover) = $plugin->write_profile_pubs($pdf, $page, $user, $settings, $fonts, 
							$x, $y, $id, $leftover, $cat, $first, 1 );
			}
		}
	}

        $pdf->save;

        return $pdf_file;
}

sub add_page
{
        my ( $plugin, $pdf, $settings, $fonts, $user, $first, $page_number ) = @_;

        my $width = $settings->{width} ? $settings->{width}/mm : 210/mm;
        my $height = $settings->{height} ? $settings->{height}/mm : 297/mm;
        my $bleed = $settings->{bleed} ? $settings->{bleed}/mm : 5/mm;
        my $crop = $settings->{crop} ? $settings->{crop}/mm : 7.5/mm;
        my $art = $settings->{art} ? $settings->{art}/mm : 10/mm;

        my $page = $pdf->page();
	$page->mediabox ($width, $height);
	$page->bleedbox( $bleed,  $bleed,  $width-$bleed, $height-$bleed );
	$page->cropbox ( $crop,  $crop,  $width-$crop,  $height-$crop );
	$page->artbox  ( $art,  $art,  $width-$art,  $height-$art );

 	my $x = 30;
	my $y = ($settings->{height} - 45);
        $page = $plugin->write_profile_header($pdf, $page, $settings, $fonts );
        $page = $plugin->write_watermark($pdf, $page, $settings, $fonts ) if $first;
	($page, $y) = $plugin->write_profile_details($pdf, $page, $user, $settings, $fonts, $x, $y ) if $first;
        $page = $plugin->write_profile_footer($pdf, $page, $user, $settings, $fonts, $page_number );
	
	return ($page, $x, $y);
}

sub write_watermark
{
        my ( $plugin, $pdf, $page, $settings, $fonts ) = @_;
        my $repo = $plugin->repository;

	my $watermark = $page->text;
	my $next_y = $settings->{watermark_y}/mm;
	$watermark->fillcolor($settings->{watermark_font_colour_1});
	my $wht = $watermark->textlabel( ($settings->{watermark_x})/mm, 
					$next_y, 
					$fonts->{watermark}, 
					($settings->{watermark_font_size})/pt, 
					$repo->phrase( "watermark:publication_list_1" ), 
					-rotate => 90);
	$next_y += $wht;
	$watermark->fillcolor($settings->{watermark_font_colour_2});
	$wht = $watermark->textlabel( ($settings->{watermark_x})/mm, 
					$next_y, 
					$fonts->{watermark}, 
					($settings->{watermark_font_size})/pt, 
					" ".$repo->phrase( "watermark:publication_list_2" ), 
					-rotate => 90);
	$next_y += $wht;
	$watermark->fillcolor($settings->{watermark_font_colour_3});
	$wht = $watermark->textlabel( ($settings->{watermark_x})/mm, 
					$next_y, 
					$fonts->{watermark}, 
					($settings->{watermark_font_size})/pt, 
					" ".$repo->phrase( "watermark:publication_list_3" ), 
					-rotate => 90);

        return $page;
}

sub write_profile_header
{
        my ( $plugin, $pdf, $page, $settings, $fonts ) = @_;
        my $repo = $plugin->repository;

	my $header = $page->text;
	$header->font( $fonts->{header}, ($settings->{header_font_size})/pt );
	$header->fillcolor($settings->{header_font_colour});
	$header->translate( 35/mm, ($settings->{height} - 30)/mm );
     #   $header->text( $plugin->phrase( "pdf_title" ) );

	my $logo_filename = $repo->config("archiveroot")."/cfg/static/images/".$settings->{logo};
	if ( -e	$logo_filename )
	{ 
		my $logo = $page->gfx;
 		my $logo_file = $pdf->image_png($logo_filename);
 		$logo->image( $logo_file, 15/mm, ($settings->{height} - 30)/mm, 241.2, 54 );
	}

        return $page;
}

sub write_profile_details
{
        my ( $plugin, $pdf, $page, $user, $settings, $fonts, $x, $y ) = @_;
        my $repo = $plugin->repository;

	my $title = $page->text;
	$title->font( $fonts->{title}, ($settings->{title_font_size})/pt );
	$title->fillcolor($settings->{title_font_colour});
	$title->translate( ($x-2)/mm, $y/mm );
       	$title->text( EPrints::Utils::make_name_string( $user->get_value( "name" ), 1 ) );
	$title->font( $fonts->{detail}, ($settings->{font_size})/pt );
	$title->fillcolor($settings->{font_colour});
	$y -= 2;
	my $ds = $user->dataset;
	foreach my $field_name ( @{$settings->{detail_fields}} )
	{
		next unless $ds->has_field( $field_name );
		my $field = $ds->field( $field_name );
		my $val = $user->get_value( $field_name );
		next unless $val;
		$y -= 5;
		$title->translate( $x/mm, $y/mm );
       		$title->text( EPrints::Utils::tree_to_utf8($field->render_name).": " );
		$title->translate( ($x + $settings->{detail_field_offset} )/mm, $y/mm );
       		$title->text( $val );
	}		
	$title->font( $fonts->{title}, ($settings->{title_font_size})/pt );
	$title->fillcolor($settings->{title_font_colour});
	$y -= 10;
	$title->translate( ($x-2)/mm, $y/mm );
       	$title->text( $plugin->phrase( "pdf_detail_title" ) );
	
        return ($page, $y);
}




sub write_profile_pubs
{
        my ( $plugin, $pdf, $page, $user, $settings, $fonts, $x, $y, $id, $details, $subtitle, $first, $continuation ) = @_;
        my $repo = $plugin->repository;

	if ( $first || $continuation )
	{
		$y -= 10;
		my $title = $page->text;
		$title->font( $fonts->{sub_title}, ($settings->{sub_title_font_size})/pt );
		$title->fillcolor($settings->{sub_title_font_colour});
		$title->translate( ($x-2)/mm, $y/mm );
	        $title->text( $plugin->phrase( "pdf_title_".$subtitle ) );
		$title->text( " ".$plugin->phrase( "pdf_title_continuation" ) ) if $continuation;
		$y -= 4;
	}
	$y -= 4;
	
	my $detail = $page->text;
	$detail->font( $fonts->{detail}, ($settings->{font_size})/pt );
	$detail->fillcolor($settings->{font_colour});
	$detail->translate( $x/mm, $y/mm );
	$detail->lead( 14 ); # the distance between lines in pt
	my $available = $y -28; # 2 lines left for the footer
	my ($leftover, $height) = $detail->section( $details, 150/mm , $available/mm, -align => "justified", -indent => '0' );

	my $used = $available - ($height * mm);
	# add the hyperlink
	my $annotation = $page->annotation;
	my $llx = $x/mm;
	my $lly = ($y-$used+3)/mm;
	my $urx = ($x+150)/mm;
	my $ury = ($y+5)/mm;
	my @rect = ( $llx, $lly, $urx, $ury );
	$annotation->rect(@rect);
	my $item_url = $repo->config("http_url");
	$item_url .= "/".$id."/";
	$annotation->url( $item_url );

	$y -= $used;
        return ($page, $y, $leftover);
}


sub write_profile_footer
{
        my ( $plugin, $pdf, $page, $user, $settings, $fonts, $page_number ) = @_;
        my $repo = $plugin->repository;

        my $date_now = $plugin->get_date_now;
        my @date_bits = split /-/, $date_now;
	my $footer = $page->text;
	$footer->font( $fonts->{footer}, ($settings->{footer_font_size})/pt );
	$footer->fillcolor($settings->{footer_font_colour});
	$footer->translate( ($settings->{footer_x})/mm, ($settings->{footer_y})/mm );
        $footer->text( $plugin->phrase( "pdf_footer", day=>$date_bits[2], month=>$date_bits[1], year=>$date_bits[0] ) );
	my $page_number_offset = $settings->{footer_page_x};
	$page_number_offset -= 3 if $page_number > 9;
	$page_number_offset -= 3 if $page_number > 99;
	$footer->translate( $page_number_offset/mm, ($settings->{footer_y})/mm );
        $footer->text( $plugin->phrase( "pdf_footer_page", page=>$page_number ) );

        return $page;
}




sub get_date_now
{
        my( $plugin ) = @_;

        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        $year += 1900;
        $mon++;
        my $date_now = join( "-", $year, $mon, $mday );
        return $date_now;
}



1;


