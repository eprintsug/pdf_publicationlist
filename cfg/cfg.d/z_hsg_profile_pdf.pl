#
# publication list settings
#


# enable the appropriate plugins
$c->{plugins}{'Screen::User::ExportPdf'}{params}{disable} = 0;
$c->{plugins}{'Export::UserPDF'}{params}{disable} = 0;

# allow anyone to download the user profile/publication list
push @{$c->{public_roles}}, "+user/export";

$c->{profile_pdf_settings} = {

	cache_pdf => 0,
	filename_prefix => "publication_list_",
	filename_inc_name => 1,
	filename_ext => "pdf",
	width => 210,
	height => 297,
	bleed => "5",
	crop => "7.5",
	art => "10",
	logo => "images-unisg-logo-300dpi.png", # needs to be a png format image such as "sitelogo.png",
	watermark_x => 15,
	watermark_y => 35,
	footer_x => 25,
	footer_page_x => 175,
	footer_y => 15,

	header_font_name => "Helvetica-Bold",
	header_font_size => "18",
	header_font_colour => "black",

	title_font_name => "Helvetica-Bold", 
	title_font_size => "14",
	title_font_colour => "#34995f",

	sub_title_font_name => "Helvetica-Bold",
	sub_title_font_size => "10",
	sub_title_font_colour => "black",

	watermark_font_name => "Helvetica-Bold", 
	watermark_font_size => "9",
	watermark_font_colour_1 => "#444444",
	watermark_font_colour_2 => "#34995f",
	watermark_font_colour_3 => "#444444",

	font_name => "Helvetica",
	font_size => "10",
	font_colour => "black",

	footer_font_name => "Helvetica",
	footer_font_size => "10",
	footer_font_colour => "#444444",

	detail_fields => [qw/ org street post_code city phone email /],
	detail_field_offset => 30,

	category => {
		article		=>	"article",
		book_section	=>	"book",
		monograph	=>	"book",
		conference_item	=>	"article",
		book		=>	"book",
		thesis		=>	"general",
		patent		=>	"general",
		artefact	=>	"general",
		exhibition	=>	"general",
		composition	=>	"general",
		performance	=>	"general",
		image		=>	"general",
		video		=>	"general",
		audio		=>	"general",
		dataset		=>	"general",
		experiment	=>	"general",
		teaching_resource =>	"general",
		other		=>	"general",
	},
};



{
# Package for extensions to EPrints::Script::Compiled
package EPrints::Script::Compiled;

use strict;

sub run_get_publication_list_url
{
        my( $self, $state, $user, $field ) = @_;
        if( ! $user->[0]->isa( "EPrints::DataObj::User" ) )
        {
                $self->runtime_error( "Can only call get_publication_list_url() on user objects not ".
                        ref($user->[0]) );
        }
	my $pdf_filename = "publication_list.pdf";
        my $repo = $user->[0]->repository;
	my $plugin = $repo->plugin( "Export::UserPDF" );
	$pdf_filename = $plugin->form_filename( $user->[0] ) if $plugin;

	my $href = "/cgi/export/user/".$user->[0]->get_id;
	$href .= "/UserPDF/";
	$href .= $pdf_filename;
	my $url = $repo->xml->create_element( "a", href=>$href, target=>"_blank" );
	$url->appendChild( $repo->html_phrase( "publication_list:link:title" ) );
        return [ $url, "XHTML"  ];
}

}








