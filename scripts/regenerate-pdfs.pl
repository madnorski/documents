#!/usr/bin/env perl
use strict;
use warnings;
use Carp;

use WWW::Mechanize;
use Web::Scraper;
use File::Slurp;
use FindBin;
use Data::Printer;
use Text::Handlebars;
use File::Basename;

binmode STDOUT, ':encoding(UTF-8)';

my $genList = {
    "MadNorSki Bylaws" => {
        source => 'https://github.com/madnorski/documents/blob/master/club-bylaws.md',
        output => 'bylaws',
        template => 'madnorski-base-markdown.html'
    }
};

my $UAString = "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Googlebot/2.1; +http://www.google.com/bot.html) Safari/537.36.";
my $mech = WWW::Mechanize->new(
    autocheck => 0,
    PERL_LWP_SSL_VERIFY_HOSTNAME => 0,
    verify_hostname => 0,
    ssl_opts => {
        verify_hostname => 0
    }
);
$mech->agent($UAString);
my $templates = {};

my $scraper = scraper {
    process 'article.markdown-body', 'content' => sub {
        return $_->as_HTML;
    };
};

foreach my $docName (keys %$genList) {
    my $doc = $genList->{$docName};
    my $tmplFile = $FindBin::Bin . '/template/' . $doc->{template};
    my $outFileHTML = $FindBin::Bin . '/rendered/' . $doc->{output} . '.html';
    my $outFilePDF = $FindBin::Bin . '/rendered/' . $doc->{output} . '.pdf';
    $mech->get($doc->{source});
    if (!$mech->success) {
        croak "Couldn't load " . $doc->{source} . "\n";
    }

    my $content = $mech->content;
    my $results = $scraper->scrape($content);
    $content = join('', map { $_ =~ m/<h[1-6]/i ? "<div class=\"pageBreakPrevent\">\n" . $_ . "</div>\n" : $_ } split(/(?=<h[1-6])/i, $results->{content}));

    if (!$templates->{$doc->{template}}) {
        $templates->{$doc->{template}} = read_file($tmplFile);
    }
    my $output = $templates->{$doc->{template}};
    $output =~ s/{{title}}/$docName/gi;
    $output =~ s/{{content}}/$content/gi;
    write_file($outFileHTML, $output);
    print "Wrote $outFileHTML\n";
    #system('wkhtmltopdf', '--footer-center [page]/[topage]', $outFileHTML, $outFilePDF);
    system('wkhtmltopdf', $outFileHTML, $outFilePDF);
}