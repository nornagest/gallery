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

my $base_dir = $config->{base_dir};
my $gallery_dir = $config->{gallery_dir};
my $preview_dir = $config->{preview_dir};
my $thumb_dir = $config->{thumb_dir};
my $preview_size = $config->{preview_size};
my $thumb_size = $config->{thumb_size};
my $default_permissions = $config->{default_permissions};
my $log_dir = $config->{log_dir};
my $log_level = $config->{log_level};

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

get '/' => sub {
    my $self = shift;
    my @gallery_dirs;

    if ( $#gallery_dirs <= 0 ) {
        opendir( my $dh, "public/" ) or $log->info("can't opendir public: $!");
        @gallery_dirs =
          sort { $a cmp $b } grep { !/^\./ && -d "public/$_" } readdir($dh);
        closedir $dh;
    }

    $self->stash( gal_dirs => \@gallery_dirs );

    my $remote_addr = $self->tx->remote_address;
    my $ua          = $self->req->headers->user_agent;
    my $path        = $self->req->url->to_abs->path;
    my $method      = $self->req->method;
    $log->info("$remote_addr $method $path $ua");

    #$self->reply->static('index.html');

} => 'index';

# this block does the work of building the viewing of the gallery
# start is the first part of an array slice to view chunks of images
# at a time rather than all on one page
get '/:dir/:start' => { start => 0 } => sub {
    my $self        = shift;
    my $directory   = $self->param('dir');
    my $slice_start = $self->param('start');

    # how many images should be shown on a page
    # we want 30 at a time
    my $slice_end = $slice_start + 29;
    my $prev_slice;
    my $next_slice;
    my $title;
    my @pics;

    my $remote_addr = $self->tx->remote_address;
    my $ua          = $self->req->headers->user_agent;
    my $path        = $self->req->url->to_abs->path;
    my $method      = $self->req->method;
    $log->info("$remote_addr $method $path $ua");

    # only build the thumbnail image array once
    if ( $#pics <= 0 ) {
        @pics = map { s/public//r }
          grep {
/\.[Jj][Pp][Ee][Gg]$|\.[Jj][Pp][Gg]$|\.[Pp][Nn][Gg]$|\.[Gg][Ii][Ff]$/
          } glob "public/$directory/thumbs/*";

 # if there are no thumbnails then build the images from the directory you chose
        if ( $#pics <= 0 ) {
            @pics = map { s/public//r }
              grep {
/\.[Jj][Pp][Ee][Gg]$|\.[Jj][Pp][Gg]$|\.[Pp][Nn][Gg]$|\.[Gg][Ii][Ff]$/
              } glob "public/$directory/*";
        }

        # get the title of the gallery from the .title file
        if ( open my $ifh, "<", "public/$directory/.title" ) {
            while (<$ifh>) {
                $title .= $_;
            }
            close $ifh;
        }
        else {
            $log->info("could not open (public/$directory/.title): $!");
        }

    }

    # in order to show the next and previous page links correctly
    # we need to know the previous slice from the current number
    # we are on
    $prev_slice = $slice_start - 30;

    if ( $prev_slice < 0 ) {
        $prev_slice = 0;
    }

    if ( $slice_end > $#pics ) {
        $slice_end  = $#pics;
        $next_slice = $#pics;
    }
    else {
        $next_slice = $slice_end + 1;
    }

    # grab only what we need from the entire list of images
    my @send_pics = @pics[ $slice_start .. $slice_end ];

    $self->stash( gallery => \@send_pics );
    $self->stash( prev    => $prev_slice );
    $self->stash( next    => $next_slice );
    $self->stash( dir     => $directory );
    $self->stash( header  => $title );
    $self->stash( end     => $#pics );

    $self->render('gallery');
};

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
View the following galleries

@@ gallery.html.ep
% layout 'view_gallery';
% title 'Welcome';

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
  <title><%= title %></title>
  </head>
  <body>
    <%= content %>
    <p />
    % foreach my $dir ( @$gal_dirs ) {
      <%= link_to $dir  => "/$dir/0" %> <br>
    % }
  </body>
</html>

@@ layouts/view_gallery.html.ep
<!DOCTYPE html>
<html>
  <head>
  <title><%= title %></title>

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

  <script>
    function show_img(med_img, down_img) {
      document.getElementById("view_pic").src = med_img;
      document.getElementById("download").href = down_img;
    }
  </script>

  </head>
  <body>
  
    <b><%= $header %></b>
    <p />    
  
    <div class="thumbs">
      % my $counter = 0;
      % my $show_pic;
      % my $med_pic;
      % my $orig_pic;
      % my $download_pic;
      % my $viewer_pic;
      
      % foreach my $img ( @$gallery ) {
        % $show_pic = $img;
        % $show_pic =~ s/\/thumbs//g;
        % $show_pic =~ s/thumb_//;
        % $med_pic = $show_pic;
        % $orig_pic = $show_pic;
        % $orig_pic =~ s/($dir)/$1\/originals/;

        % if ( $counter == 0 ) {
        %  $viewer_pic = $show_pic;
        %  $download_pic = $orig_pic
        % }

        % my $js_code = "show_img('$med_pic','$orig_pic');return false;";
        % my $image_link = image($img);
        % my $link_tag = link_to('XXX' => '#', onclick => $js_code);
        % $link_tag =~ s/XXX/$image_link/;
        <div id='x' class='thumb'>
          <%== $link_tag %> 
        </div>
        % $counter++;
      % }
    </div>
     
    <div class="clear"></div>
    <div class="viewer">
      % if ( $next > 30 ) {
        <%= link_to Prev => "/$dir/$prev", class => 'prev' %>
      % }
      % if ( $next < $end ) {
        <%= link_to Next => "/$dir/$next", class => 'next' %>
      % }
      <div class="clear"></div> <p />
      <%= image $viewer_pic, id => 'view_pic' %> <p />
      <%= link_to "Front page" => 'index', class => 'left' %>
      <%= link_to 'Download original' => $download_pic, class => 'right', id => 'download' %>
    </div>
  </body>
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

    index.html - hand written html file pointing to your directories

    Directory1/
      .title - contents of file is the title of the gallery
      image1.jpg - a medium size image
      image2.jpg - a medium size image
      image3.jpg - a medium size image
      
      thumbs/
        thumb_image1.jpg
        thumb_image2.jpg
        thumb_image3.jpg
        
      originals/
        image1.jpg - the original image
        image2.jpg - the original image
        image3.jpg - the original image

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

