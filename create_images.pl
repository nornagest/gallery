#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: create_images.pl
#
#        USAGE: ./create_images.pl
#
#  DESCRIPTION:
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (),
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 08/12/2015 04:35:28
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Carp;

use Image::Magick;
use File::Find;
use File::Copy;

my $base_dir            = 'public';
my $gallery_dir         = 'gallery';
my $preview_dir         = 'previews';
my $thumb_dir           = 'thumbs';
my $preview_size        = 600;
my $thumb_size          = 80;
my $default_permissions = 0755;

my %formats = ( JPEG => 'jpg', PNG => 'png', GIF => 'gif', BMP => 'bmp' );

my $dir = "$base_dir/$gallery_dir";

map { process_file($_) } read_dir($dir);

sub read_dir {
    my $dir = shift;
    my @contents;

    mkdir "$base_dir/$preview_dir", $default_permissions
      unless -e "$base_dir/$preview_dir";
    mkdir "$base_dir/$thumb_dir", $default_permissions
      unless -e "$base_dir/$thumb_dir";

    finddepth(
        {
            wanted =>
              sub { push @contents, $File::Find::name if should_process($_); },
            follow => 1
        },
        $dir
    );
    return @contents;
}

sub should_process {
    my $file = shift;
    return -e $file && -f $file && -w $file;
}

sub create_dirs {
    my $path = shift;

    my @parts = split '/', $path;
    for ( my $i = 2 ; $i <= $#parts ; $i++ ) {
        $path = join '/', @parts[ 2 .. $i ];
        my $preview_path = "$base_dir/$preview_dir/$path";
        my $thumb_path   = "$base_dir/$thumb_dir/$path";

        print "Creating directories for $path\n";
        mkdir $preview_path, $default_permissions
          unless -e $preview_path && -d $preview_path;
        mkdir $thumb_path, $default_permissions
          unless -e $thumb_path && -d $thumb_path;
    }
}

sub process_file {
    my $file = shift;
    print "Processing $file\n";
    my ( $path, $name, $ext );
    if ( $file =~ /(.*)\/(.*)\.(.*)/ ) {
        ( $path, $name, $ext ) = ( $1, $2, $3 );
    }
    return unless $1 && $2 && $3;
    return unless grep { $3 eq $_ } values %formats;

    my $preview_path = $path;
    $preview_path =~
      s/$base_dir\/$gallery_dir\/(.*)$/$base_dir\/$preview_dir\/$1/;
    my $thumb_path = $path;
    $thumb_path =~ s/$base_dir\/$gallery_dir\/(.*)$/$base_dir\/$thumb_dir\/$1/;
    create_dirs($path) unless -e $preview_path && -e $thumb_path;

    my $image = Image::Magick->new;
    my ( $width, $height, $size, $format ) = $image->Ping($file)
      or carp "Can't ping $file $1\n";
    return unless $width && $height;

    my $preview_file = "$preview_path/$name.$ext";
    my $thumb_file   = "$thumb_path/$name.$ext";

    my $e;
    $e = $image->Read($file);
    carp "$e" && return if $e;
    if ( $width > $preview_size || $height > $preview_size ) {
        $e = $image->Scale( geometry => "${preview_size}x$preview_size" );
        carp "$e" if $e;
    }
    $e = $image->Write($preview_file);
    carp "$e" if $e;

    if ( $width > $thumb_size || $height > $thumb_size ) {
        $e = $image->Scale( geometry => "${thumb_size}x$thumb_size" );
        carp "$e" if $e;
    }
    $e = $image->Write($thumb_file);
    carp "$e" if $e;
}
