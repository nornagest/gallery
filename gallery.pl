#!/usr/bin/env perl
use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::Log;

our $VERSION = "1.2";

# Documentation browser under "/perldoc"
plugin 'PODRenderer' => { name => 'pod' };

get '/pod';

my $config = plugin 'Config';
my @image_ext = ('jpg', 'png', 'gif', 'bmp');
my $size = 30;

my $base_dir = $config->{base_dir};
my $gallery_dir = $config->{gallery_dir};
my $preview_dir = $config->{preview_dir};
my $thumb_dir = $config->{thumb_dir};
my $preview_size = $config->{preview_size};
my $thumb_size = $config->{thumb_size};
my $default_permissions = $config->{default_permissions};
my $log_dir = $config->{log_dir};
my $log_level = $config->{log_level};
my $log_file = $config->{log_file};

# if the log directory does not exist then create it
if ( !-d $log_dir ) {
    print "Creating $log_dir directory\n";
    mkdir $log_dir, 0755 or die "Cannot create $log_dir: $!\n";
}

# setup Mojo logging to use the log directory we just created
# default the log level to info
my $log = Mojo::Log->new(
    path  => "$log_dir/$log_file",
    level => $log_level
);

sub is_image {
    my $file = shift;
    for my $ext (@image_ext) {
        return 1 if lc $file =~ /\.$ext$/;
    }
    return undef;
}

get '/*route' => { route => ''} => sub {
    my $c = shift;

    my $remote_addr = $c->tx->remote_address;
    my $ua          = $c->req->headers->user_agent;
    my $url_path    = $c->req->url->to_abs->path;
    my $method      = $c->req->method;
    $log->info("$remote_addr $method $url_path $ua");

    my $route = $c->stash('route');
    my $start = 0; 
    ($route, $start) = ($1, $2) if $route =~ /^(.*)\/(\d+)\/?$/;
    my %dir = (
        route => $route, 
        thumb => "$thumb_dir/$route",
        preview => "$preview_dir/$route",
        gallery => "$gallery_dir/$route"
    );
    my $title = 'Index';
    $title = $2 if $route =~ /^(.*\/)?(.+)$/;

    my @galleries;
    if ( $#galleries <= 0 && -d "$base_dir/$dir{gallery}") {
        opendir( my $dh, "$base_dir/$dir{gallery}" ) 
            or $log->info("can't opendir $base_dir/$dir{gallery}: $!") and die $!;
        @galleries =
          sort { $a cmp $b } 
          map { $route ? "$route/$_" : $_ }
          grep { !/^\./ && -d "$base_dir/$dir{gallery}/$_" } readdir($dh);
        closedir $dh;
    }

    my @pics;
    # only build the thumbnail image array once
    if ( $#pics <= 0 ) {
        @pics = 
          map { s/$base_dir\/$dir{thumb}//r }
          grep { is_image($_) }
          glob "$base_dir/$dir{thumb}/*";
    }
    
    my $end = $start + $size -1;
    $end = $#pics if $end > $#pics;
    my $prev = $start - $size;
    $prev = undef if $prev < 0;
    my $next = $end + 1;
    $next = undef if $next > $#pics;

    # grab only what we need from the entire list of images
    my @images = @pics[$start..$end];

    $c->stash( galleries => \@galleries );
    $c->stash( pics => \@images );
    $c->stash( prev    => $prev );
    $c->stash( next    => $next );
    $c->stash( dir     => \%dir );
    $c->stash( header  => $title );
} => 'gallery';

app->start;

__DATA__

@@ gallery.html.ep
% layout 'default';
% title $header;

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <script>
    function show_img(med_img, down_img) {
      document.getElementById("view_pic").src = med_img;
      document.getElementById("download").href = down_img;
    }
  </script>

  <head>
  <title><%= title %></title>
  </head>
  <body>
    <div class="header">
        <b><%= $header %></b>
    </div>
    <div class="clear"></div>
    <div class="galleries">
        <%= link_to 'Index' => '/', class => 'left' %> </br>
        % foreach my $directory ( @$galleries ) {
            <%= link_to $directory  => "/$directory" %>
        % }
    </div>
    <div class="clear"></div>
    <div class="thumbs">
      % my $counter = 0;
      % my ($download, $viewer);

      % foreach my $pic ( @$pics ) {
        % my %image = ( 
            % name => $pic, 
            % thumb => $dir->{thumb} . '/' . $pic,
            % preview => $dir->{preview} . '/' . $pic,
            % gallery => $dir->{gallery} . '/' . $pic
        % );
        % if( !$counter ) {
            % $viewer = $image{preview};
            % $download = $image{gallery};
        % }

        % my $js_code = "show_img('" . $image{preview} . "','" . $image{gallery} . "');return false;";
        % my $image_link = image $image{thumb};
        % my $link_tag = link_to('XXX' => '#', onclick => $js_code);
        % $link_tag =~ s/XXX/$image_link/;
        <div class='thumb'>
          <%== $link_tag %> 
        </div>
        % $counter++;
      % }
    </div>
     
    <div class="clear"></div>
    <div class="viewer">
      % if (@$pics) {
         % if ( $prev  ) {
           <%= link_to 'Prev' => "/" . $dir->{route} . "/$prev", class => 'prev' %>
         % }
         % if ( $next ) {
           <%= link_to 'Next' => "/" . $dir->{route} . "/$next", class => 'next' %>
         % }
         <div class="clear"></div> <p />

         <%= image $viewer, id => 'view_pic' %> <p />
         <%= link_to 'Download original' => $download, class => 'right', id => 'download' %>
      % }
    </div>
  </body>

  <style type="text/css">
    .thumbs {
      margin-left: 5px;
      margin-right:5px;
      float:top;
    }
    
    .thumb {
      max-height: 90px;
      min-width: 90px;
      padding-left: 5px;
      padding-right:5px;
      float: left;
    }
    
    .viewer {
      padding-left: 20px;
      padding-bottom: 10px;
      float:left;
    }
    
    .clear {
      clear: both;
    }
    
    .prev {
      float: left;
    }
    
    .next {
      float: right;
      padding-left: 20px;
    }

    .right {
      float: right;
    }
    .left {
      float: left;
    }
  </style>
</html>

@@ pod.html.ep
<%= pod_to_html begin %>
=head1 NAME

gallery.pl - Mojolicious based web gallery

=head1 SYNOPSIS

Web based photo gallery using Mojolicious.  It follows a similar format to Trent Foley's gallerific
http://jquery.kvijayanand.in/galleriffic/

=head1 DESCRIPTION

Web based photo gallery using Mojolicious.  You will see at most 30 images at a time on a page and can page through the next and previous groups of 30.  When you click on a thumbnail image it will show in a larger viewing area just to the right of the thumbnails.

=head1 README

In order to successfully use this script you need to follow a standard directory structure in order to allow the script to work properly.  Read the CONFIGURATION section below.

=head1 FORMATS

=over 3

=item jpg

=item jpeg

=item gif

=item png

=back

=head1 CONFIGURATION

Along side gallery.pl you need a directory called public/.  Inside public/ will be your directories of pictures.  Inside those directories will be a thumbs/ and originals/ directory.  The public/ directory is the dependency of Mojolicious when serving static files.

public/
    
    gallery/
        Directory1/
            image1.jpg - the original image
            image2.jpg - the original image
            image3.jpg - the original image
    previews/
        Directory1/
            image1.jpg - a medium size image
            image2.jpg - a medium size image
            image3.jpg - a medium size image
      
    thumbs/
        Directory1/
            image1.jpg - a thumbnail
            image2.jpg - a thumbnail
            image3.jpg - a thumbnail

=head2 CONFIGURATION

  Please fill in the appropriate fields in the gallery.conf file.

=head1 RUNNING

C<<< # hypnotoad -f gallery.pl >>>

=head1 PREREQUISITES

=over 1

=item Mojolicious::Lite

=back

=head1 SCRIPT CATEGORIES

Web

=head1 AUTHOR

Mike Plemmons, <mikeplem@cpan.org>

=head1 LICENSE

Copyright (c) 2014, Mike Plemmons
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Mike Plemmons nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL MIKE PLEMMONS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
<% end %>
__END__

