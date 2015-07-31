package EPrints::Plugin::Screen::User::ExportPdf;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	if( defined $self->{session} && !$self->{session}->config( "meprints_enabled" ) )
	{
		return $self;
	}

	$self->{actions} = [qw/ write /];

	$self->{appears} = [
		{
			place => 'user_actions',
			action => 'write',
			position => 1100,
		}
	];

	return $self;
}

sub from
{
	my( $self ) = @_;
        my $repo = $self->{repository};
	my $action_id = $self->{processor}->{action};
	if ( $action_id && $action_id eq "write" )
	{
                $self->export;
	}
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless( defined $self->{session} && defined $self->{session}->current_user );

	my $user = EPrints::Plugin::MePrints::get_user( $self->{session} );
	return $self->{session}->current_user->allow( 'user/edit', $user );
}

sub allow_write
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub wishes_to_export
{
        my( $self ) = @_;

        return 1;
}

sub export_mimetype
{
        my( $self ) = @_;
	return "application/pdf";
}

sub export
{
        my( $self ) = @_;

        my $repo = $self->{repository};
	my $pdf_plugin = $repo->plugin( "Export::UserPDF" ); 
	my $user_id = $repo->param("userid" );
	if ( $user_id && $pdf_plugin )
	{
		my $user_ds = $repo->dataset( "user" );
		my $user = $user_ds->dataobj( $user_id );
		if ( $user )
		{
			$repo->send_http_header( "content_type"=>$self->export_mimetype );
			print $pdf_plugin->output_dataobj( $user );
		}
	}
}


1;


