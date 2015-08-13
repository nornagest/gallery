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

my $root                = 'public';
my $thumbs              = 'thumbs';
my $originals           = 'originals';
my $title               = '.title';
my $thumb_prefix        = 'thumb_';
my $default_permissions = 0755;
my @image_ext       = ( 'jpg', 'jpeg', 'png', 'gif' );

my @gallery_dirs =
  sort { $a cmp $b }
  grep { !/^\./ && -d "$root/$_" } read_dir($root);

for my $dir (@gallery_dirs) {
    print "Processing $root/$dir\n";
    my @files = check_and_create_defaults($dir);

    print "Processing files...\n";
    for my $file (@files) {
        my $medium_file = "$root/$dir/$file";
        my $thumb_file = "$root/$dir/$thumbs/$thumb_prefix$file";
        my $original_file = "$root/$dir/$originals/$file";

        my $image = Image::Magick->new;

        $image->Read($medium_file);

        #my $x = $image->Identify;

        if(-e $original_file) {
            print "$original_file exists\n";
        } else {
            print "Writing $original_file\n";
            $image->Write($original_file);
            write_medium($image, $medium_file);
        }
        if(-e $thumb_file) {
            print "$thumb_file exists\n";
        } else {
            write_thumb($image, $thumb_file);
        }
    }
}

sub write_medium {
    my ($image, $medium) = @_;
    $image->Scale(geometry => '600x600');
    print "Writing $medium\n";
    $image->Write($medium);
}

sub write_thumb {
    my ($image, $thumb) = @_;
    $image->Scale(geometry => '80x80');
    print "Writing $thumb\n";
    $image->Write($thumb);
}

sub read_dir {
    my $dir = shift;
    opendir( my $dh, $dir ) or die "can't opendir $dir: $!";
    my @contents = readdir $dh;
    closedir $dh;
    return @contents;
}

sub check_and_create_defaults {
    my $dir   = shift;
    my @files = read_dir("$root/$dir");

    my $has_title = grep { /^$title$/ } @files;
    if ($has_title) {
        print "$title found\n";
    }
    else {
        open( my $fh, '>', "$root/$dir/$title" ) or die "can't open $title $!";
        print $fh $dir;
        close $fh;
        print "$title created\n";
    }

    my $has_thumb_dir = grep { /^$thumbs$/ && -d "$root/$dir/$thumbs" } @files;
    if ($has_thumb_dir) {
        print "$thumbs found\n";
    }
    else {
        mkdir "$root/$dir/$thumbs", $default_permissions
          or die "Cannot create $thumbs $!\n";
        print "$thumbs created\n";
    }
    my $has_originals_dir =
      grep { /^$originals$/ && -d "$root/$dir/$originals" } @files;
    if ($has_originals_dir) {
        print "$originals found\n";
    }
    else {
        mkdir "$root/$dir/$originals", $default_permissions
          or die "Cannot create $originals $!\n";
        print "$originals created\n";
    }

    return grep { !/^\./ && -f "$root/$dir/$_" && has_image_extension($_) } @files;
}

sub has_image_extension {
    my $file = shift;
    for my $ext (@image_ext) {
        return 1 if lc $file =~ /\.$ext$/;
    }
    return undef;
}
