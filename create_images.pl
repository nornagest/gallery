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

use Image::Magick;
use File::Find;
use File::Copy;

my $base_dir = 'public';
my $gallery_dir = 'gallery';
my $preview_dir = 'previews';
my $thumb_dir = 'thumbs';
my $preview_size = 600;
my $thumb_size = 80;
my $default_permissions = 0755;

my %formats = (JPEG => 'jpg', PNG => 'png', GIF => 'gif', BMP => 'bmp');

my $dir = "$base_dir/$gallery_dir";
map { process_file($_) } read_dir($dir);

sub read_dir {
  my $dir = shift;
  my @contents;

  mkdir "$base_dir/$preview_dir", $default_permissions unless -e "$base_dir/$preview_dir";
  mkdir "$base_dir/$thumb_dir", $default_permissions unless -e "$base_dir/$thumb_dir";
  
  finddepth(
      #sub { push @contents, $File::Find::name if avoid_dots($_); }, 
      sub { push @contents, $File::Find::name if should_process($_); }, 
      $dir);
  return @contents;
}

sub avoid_dots {
  my $file = shift;
  print "DEBUG: File: $file\n";
  return undef if $file =~ /^\.*$/;
  return 1;
}

#instead of avoid_dots
sub should_process {
  my $file = shift;
  return -e $file && -f $file && -w $file;
}

sub process_file {
  my $file = shift;
  my ($path, $name, $ext);
  if($file =~ /(.*)\/(.*)\.(.*)/) {
    ($path, $name, $ext) = ($1, $2, $3);
  }

  print "\n$path ";
  my $preview_path = $path;
  $preview_path =~ s/$base_dir\/$gallery_dir\/(.*)$/$base_dir\/$preview_dir\/$1/;
  print "$preview_path ";
  mkdir $preview_path, $default_permissions or die $! unless -e $preview_path && -d $preview_path ;
  my $thumb_path = $path;
  $thumb_path =~ s/$base_dir\/$gallery_dir\/(.*)$/$base_dir\/$thumb_dir\/$1/;
  print "$thumb_path";
  mkdir $thumb_path, $default_permissions or die $! unless -e $thumb_path && -d $thumb_path;

  my $image = Image::Magick->new;
  my ($width, $height, $size, $format) = $image->Ping($file);

  my $preview_file = "$preview_path/$name.$ext";
  my $thumb_file = "$thumb_path/$name.$ext";

  $image->Read($file);
  if($width > $preview_size || $height > $preview_size) {
    $image->Scale(geometry => "${preview_size}x$preview_size");
  }
  $image->Write($preview_file);
  if($width > $thumb_size || $height > $thumb_size) {
    $image->Scale(geometry => "${thumb_size}x$thumb_size");
  }
  $image->Write($thumb_file);
}
