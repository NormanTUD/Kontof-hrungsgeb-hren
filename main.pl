#!/usr/bin/perl

use strict;
use warnings;
use Firefox::Marionette();
use v5.10;
use utf8;
use Encode;
binmode(STDOUT, ":utf8");
use open qw(:std :utf8);
use open ":encoding(utf8)";

print "Starting Firefox\n";
my $marionette = Firefox::Marionette->new();
print "Firefox started\n";

print "Name?\n";
my $name = <>;

print "Strasse?\n";
my $strasse = <>;

print "Plz?\n";
my $plz = <>;

print "Ort?\n";
my $ort = <>;

print "IBAN?\n";
my $iban = <>;

chomp $strasse;
chomp $plz;
chomp $name;
chomp $ort;
chomp $iban;

print "Getting data\n";
my $firefox = $marionette->go('https://www.iban-rechner.de/iban_validieren.html');
print "Loaded\n";

my $xpath_accept_cookies = q#/html/body/div/div[2]/div[3]/button#;
my $xpath_input = "/html/body/div[2]/div/div/div/div[2]/div[2]/div/form/table/tbody/tr/td[1]/input[1]";
my $xpath_submit = "/html/body/div[2]/div/div/div/div[2]/div[2]/div/form/table/tbody/tr/td[1]/button";
my $xpath_bankname = "/html/body/div[2]/div/div/div/div[2]/div[2]/div/fieldset[3]/p[4]";
my $xpath_bankadresse = "/html/body/div[2]/div/div/div/div[2]/div[2]/div/fieldset[3]/p[5]";

print "Sleeping 3 seconds\n";
sleep 3;

sub cookiebanner {
	my $js_cookiebanner = q#
	function getElementByXpath(path) {
		return document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
	};
	var elem = getElementByXpath("/html/body/div[5]");
	if (elem) {
		elem.remove();
	}
#;

	$firefox->script($js_cookiebanner);

	print "Sleeping 3 seconds for JS to take effect...\n";
	sleep 3;

}

sub get_data {
	sleep 1;

	print "Typing IBAN...\n";

	eval "Avoiding Cookie banner";

	while ($@) {
		cookiebanner();

		eval {
			$firefox->find($xpath_input)->type($iban);

			print "Clicking submit\n";
			$firefox->find($xpath_submit)->click();
		};

		if($@) {
			print "Typing IBAN again...\n";
			
			cookiebanner();

			$firefox->find($xpath_input)->type($iban);
		}
	}

	cookiebanner();

	my $bankname_element = $firefox->find($xpath_bankname);
	my $bankadresse_element = $firefox->find($xpath_bankadresse);

	my ($bankname_internal, $bankadresse_internal) = ($bankname_element->text, $bankadresse_element->text);

	return ($bankname_internal, $bankadresse_internal);

}

my ($bankname, $bankadresse) = (undef, undef);

while (!$bankname) {
	eval {
		($bankname, $bankadresse) = get_data();
	};
	if($@) {
		print "$@\n";
		print "Trying again\n";
		$firefox = $marionette->go('https://www.iban-rechner.de/iban_validieren.html');
	}
}

$bankname =~ s#^Bank: ##g;
$bankadresse =~ s#\n#\\\\#g;

print("$bankname, $bankadresse");

my $contents = <<EOF;
\\documentclass{g-brief2}
\\usepackage{ngerman}
\\usepackage[utf8x]{inputenc}
\\usepackage[T1]{fontenc}
\\usepackage{fourier}
\\usepackage{marvosym}

\\Adresse{$bankadresse}
\\Gruss{Viele Gr"usse,}{0cm}
\\Anrede{Sehr geehrte Damen und Herren,}
\\Betreff{R"uckerstattung Kontogeb"uhren}
\\AdressZeileA{$name}
\\AdressZeileB{$strasse}
\\AdressZeileC{$plz $ort}
\\RetourAdresse{$name, $strasse, $plz $ort}
\\Name{$name}
\\Unterschrift{$name}
\\InternetZeileA{}
\\trennlinien
\\fenstermarken
\\addtolength{\\topmargin}{0.95cm}

\\begin{document}
\\begin{g-brief}

im Zusammenhang mit dem unten bezeichneten Konto haben Sie mir seit Kontoer"offnung mittels "anderungen Ihrer AGB bzw. des Preis- und Leistungsverzeichnisses erh"ohte Entgelte berechnet.

Der Bundesgerichtshof hat am 27.04.2021 (Az. BGH XI ZR 26/20) Allgemeine Gesch"aftsbedingungen der $bankname f"ur unzul"assig erkl"art, die in der Vergangenheit branchenweit als Grundlage f"ur zahlreiche Vertrags"anderungen dienten. Dabei war das Schweigen als Zustimmung des Vertragspartners gewertet worden. Die Einf"uhrung und Erh"ohung von Geb"uhren z.B. f"ur Kontof"uhrung, Kontoausz"uge, Giro- und Kreditkarten, Dauerauftr"age oder Verwahrung ist --- soweit sie wie hier auf der Verwendung identischer oder vergleichbarer unzul"assiger Klauseln beruht --- unwirksam. Eine aktive Zustimmung im Sinne einer gesonderten Erkl"arung als Vertrags"anderung zu neuen Entgelten oder Entgelterh"ohungen habe ich nicht erteilt.

Ich fordere Sie deshalb auf, mir zur H"ohe der rechtswidrig berechneten Entgelte seit Kontoer"offnung Auskunft zu erteilen sowie diese "uberzahlten Entgelte nebst Nutzungsersatz pro Jahr in H"ohe von 5 Prozentpunkten "uber dem Basiszinssatz seit der jeweiligen Berechnung innerhalb von 14 Kalendertagen auf mein Konto mit der IBAN $iban zu "uberweisen.

\\end{g-brief}
\\end{document}

EOF
;

my $texname = qq#$iban.tex#;
my $pdfname = qq#$iban.pdf#;

open my $fh, '>', $texname;
print $fh $contents;
close $fh;

system("latexmk -pdf $texname && xdg-open $pdfname")
