package Code::TidyAll::Plugin::YAMLFrontMatter;

use strict;
use warnings;

our $VERSION = '1.000000';

use Moo;

use Encode;
use Try::Tiny qw( catch try );
use YAML::XS qw( Load );

extends 'Code::TidyAll::Plugin';

# This regular expression is taken directly from the Jekyll source code here:
# https://github.com/jekyll/jekyll/blob/c7d98cae2652b2df7ebd3c60b4f8c87950760e47/lib/jekyll/document.rb#L13
my $YAML_REGEX = qr!\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)!m;

has encoding => (
    is  => 'ro',

    # By default Jekyll 2.0 and later defaults to utf-8, so this seems
    # like a sensible default for us
    default => 'UTF-8',
);

has required_top_level_keys => (
    is      => 'ro',
    default => '',
);

has _req_keys_hash => ( is => 'lazy' );
sub _build__req_keys_hash {
    my $self = shift;
    return +{
        # note use of magical split on space to do automatic trimming
        map { $_ => 1 } split q{ }, $self->required_top_level_keys
    };
}

sub validate_file {
    my ( $self, $filename ) = @_;

    # read in the file
    my $src = do {
        open my $fh, '<:bytes', $filename
            or die "Cannot open file '$filename': $!";
        local $/ = undef;
        <$fh>;
    };

    # YAML::XS always expects things to be in UTF-8 bytes
    my $encoding = $self->encoding;
    try {
        $src = decode( $encoding, $src, Encode::FB_CROAK);
        $src = encode( 'UTF-8', $src, Encode::FB_CROAK );
    } catch {
        die "File does not match encoding '$encoding': $_";
    };

    # is there a BOM?  There's not meant to be a BOM!
    if ($src =~ /\A\x{EF}\x{BB}\x{BF}/) {
        die "Starting document with UTF-8 BOM is not allowed\n";
    }

    # match the YAML front matter.
    unless ($src =~ $YAML_REGEX) {
        die "'$filename' does not start with valid YAML Front Matter\n";
    }
    my $yaml = $1;

    # parse the YAML front matter.
    my $ds =  try {
        Load( $yaml );
    } catch {
        die "Problem parsing YAML: $_";
    };

    # check for required keys
    my $errors = '';
    for (sort keys %{ $self->_req_keys_hash }) {
        next if $ds->{ $_ };
        $errors .= "Missing required YAML Front Matter key: '$_'\n";
    }
    die $errors if $errors;
}

1;
