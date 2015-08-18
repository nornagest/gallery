#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: fix_extension.pl
#
#        USAGE: ./fix_extension.pl  
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
#      CREATED: 08/18/2015 06:04:40
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

use Image::Magick;
use File::Find;
use File::Copy;

my %formats = (JPEG => 'jpg', PNG => 'png', GIF => 'gif', BMP => 'bmp');

for my $dir (@ARGV) {
    map { check_file($_) } read_dir($dir);
}

sub read_dir {
  my $dir = shift;
  my @contents;
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

sub check_file {
  my $file = shift;
  my ($path, $name, $ext);
  if($file =~ /(.*)\/(.*)\.(.*)/) {
    ($path, $name, $ext) = ($1, $2, $3);
  } elsif ($file =~ /(.*)\/(.*)/) {
    ($path, $name, $ext) = ($1, $2, '');
  }

  my $image = Image::Magick->new;
  my ($width, $height, $size, $format) = $image->Ping($file);
  return unless $format;
  my $correct_ext = $formats{$format};
  return if $ext eq $correct_ext;

  my $new_name = "$path/$name.$correct_ext";
  move($file, $new_name);
  print "$file -> $new_name\n";
}
