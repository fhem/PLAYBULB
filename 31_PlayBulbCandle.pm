###############################################################################
# 
# Developed with Kate
#
#  (c) 2016 Copyright: Marko Oldenburg (leongaultier at gmail dot com)
#  All rights reserved
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
# $Id$
#
###############################################################################


package main;

use strict;
use warnings;
use POSIX;

use JSON;
use Blocking;

my $version = "0.4.1";



my %effects = ( 
        'Flash'         =>  '00',
        'Pulse'         =>  '01',
        'RainbowJump'   =>  '02',
        'RainbowFade'   =>  '03',
        'Candle'        =>  '04',
        'none'          =>  'FF'
    );
    
my %effectsHex = (
        '00'            =>  'Flash',
        '01'            =>  'Pulse',
        '02'            =>  'RainbowJump',
        '03'            =>  'RainbowFade',
        '04'            =>  'Candle',
        'ff'            =>  'none'
    );



sub PlayBulbCandle_Initialize($) {

    my ($hash) = @_;

    $hash->{SetFn}	    = "PlayBulbCandle_Set";
    $hash->{DefFn}	    = "PlayBulbCandle_Define";
    $hash->{UndefFn}	    = "PlayBulbCandle_Undef";
    
    $hash->{AttrList} 	    = "aColor ".
                              "aEffect ".
                              $readingFnAttributes;



    foreach my $d(sort keys %{$modules{PlayBulbCandle}{defptr}}) {
	my $hash = $modules{PlayBulbCandle}{defptr}{$d};
	$hash->{VERSION} 	= $version;
    }
}

sub PlayBulbCandle_Define($$) {

    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );
    
    return "too few parameters: define <name> PlayBulbCandle <BTMAC>" if( @a != 3 );
    

    my $name    	= $a[0];
    my $mac     	= $a[2];
    
    $hash->{BTMAC} 	= $mac;
    $hash->{VERSION} 	= $version;
    
    
    $modules{PlayBulbCandle}{defptr}{$hash->{BTMAC}} = $hash;
    readingsSingleUpdate ($hash,"state","Unknown", 0);
    $attr{$name}{room}     = "PLAYBULB";
    $attr{$name}{webCmd}    = "rgb:rgb FF0000:rgb 00FF00:rgb 0000FF:rgb FFFFFF:rgb F7FF00:rgb 00FFFF:rgb F700FF:effect";
    
    $hash->{helper}{effect}     = ReadingsVal($name,"effect","Candle"); 
    $hash->{helper}{onoff}      = ReadingsVal($name,"onoff",0); 
    $hash->{helper}{rgb}        = ReadingsVal($name,"rgb","ff0000"); 
    $hash->{helper}{sat}        = ReadingsVal($name,"sat",0); 
    $hash->{helper}{speed}      = ReadingsVal($name,"speed",120);
    
    PlayBulbCandle($hash,"onoff",1);
    
    return undef;
}

sub PlayBulbCandle_Undef($$) {

    my ( $hash, $arg ) = @_;
    
    my $mac = $hash->{BTMAC};
    my $name = $hash->{NAME};
    
    
    Log3 $name, 3, "PlayBulbCandle ($name) - undefined";
    delete($modules{PlayBulbCandle}{defptr}{$mac});

    return undef;
}

sub PlayBulbCandle_Set($$@) {
    
    my ($hash, $name, @aa) = @_;
    my ($cmd, $arg) = @aa;
    my $action;

    if( $cmd eq 'on' ) {
        $action = "onoff";
        $arg    = 1;
        
    } elsif( $cmd eq 'off' ) {
        $action = "onoff";
        $arg    = 0;

    } elsif( $cmd eq 'effect' ) {
        $action = $cmd;
        
    } elsif( $cmd eq 'rgb' ) {
        $action = $cmd;
        
    } elsif( $cmd eq 'sat' ) {
        $action = $cmd;
        
    } elsif( $cmd eq 'speed' ) {
        $action = $cmd;
    
    } elsif( $cmd eq 'color' ) {
        $action = $cmd;
    
    } else {
        my $list = "on:noArg off:noArg rgb:colorpicker,RGB sat:slider,0,5,255 effect:Flash,Pulse,RainbowJump,RainbowFade,Candle,none speed:slider,170,50,20 color:on,off";
        return "Unknown argument $cmd, choose one of $list";
    }
    
    PlayBulbCandle($hash,$action,$arg);
    
    return undef;
}

sub PlayBulbCandle($$$) {

    my ( $hash, $cmd, $arg ) = @_;
    
    my $name    = $hash->{NAME};
    my $mac     = $hash->{BTMAC};
    $hash->{helper}{$cmd}   = $arg;
    
    my $rgb         =   $hash->{helper}{rgb};
    my $sat         =   sprintf("%02x", $hash->{helper}{sat});
    my $effect      =   $hash->{helper}{effect};
    my $speed       =   sprintf("%02x", $hash->{helper}{speed});
    my $stateOnoff  =   $hash->{helper}{onoff};
    my $stateEffect =   $effect;
    my $ac          =   AttrVal( $name, "aColor", "0x16" );
    my $ae          =   AttrVal( $name, "aEffect", "0x14" );
    
    if( $cmd eq "color" and $arg eq "off") {
        $rgb    = "000000";
        $sat    = "FF";
    }



    BlockingKill($hash->{helper}{RUNNING_PID}) if(defined($hash->{helper}{RUNNING_PID}));
        
    my $response_encode = PlayBulbCandle_forRun_encodeJSON($mac,$stateOnoff,$sat,$rgb,$effect,$speed,$stateEffect,$ac,$ae);
        
    $hash->{helper}{RUNNING_PID} = BlockingCall("PlayBulbCandle_Run", $name."|".$response_encode, "PlayBulbCandle_Done", 5, "PlayBulbCandle_Aborted", $hash) unless(exists($hash->{helper}{RUNNING_PID}));
    Log3 $name, 4, "(Sub PlayBulbCandle - $name) - Starte Blocking Call";
}

sub PlayBulbCandle_Run($) {

    my ($string)        = @_;
    my ($name,$data)    = split("\\|", $string);
    my $data_json       = decode_json($data);
    
    my $mac             = $data_json->{mac};
    my $stateOnoff      = $data_json->{stateOnoff};
    my $sat             = $data_json->{sat};
    my $rgb             = $data_json->{rgb};
    my $effect          = $data_json->{effect};
    my $speed           = $data_json->{speed};
    my $stateEffect     = $data_json->{stateEffect};
    my $ac              = $data_json->{ac};
    my $ae              = $data_json->{ae};
    my $blevel;
    
    Log3 $name, 4, "(Sub PlayBulbCandle_Run - $name) - Running nonBlocking";



    ##### Abruf des aktuellen Status
    #(my $ec,my $cc,$sat,$rgb,$effect,$speed)  = PlayBulbCandle_gattCharRead($mac) if( $stateEffect eq "none" );

    #$stateEffect = "change" if( $effect eq "ff" );
    
    ##### Schreiben der neuen Char values
    PlayBulbCandle_gattCharWrite($sat,$rgb,$effect,$speed,$stateEffect,$stateOnoff,$mac,$ac,$ae);
    
    ##### Abruf des aktuellen Status
    (my $ec,my $cc,$sat,$rgb,$effect,$speed)  = PlayBulbCandle_gattCharRead($mac,$stateEffect,$ac,$ae);
    

    
    ########### Bulb an oder aus?
    if( defined($cc) and defined($ec) ) {
        $stateOnoff = PlayBulbCandle_stateOnOff($cc,$ec);
    } else {
        $stateOnoff = "error";
    }
    
    ###### Batteriestatus einlesen    
    $blevel = PlayBulbCandle_readBattery($mac);
    


    Log3 $name, 4, "(Sub PlayBulbCandle_Run - $name) - Rückgabe an Auswertungsprogramm beginnt";
    my $response_encode = PlayBulbCandle_forDone_encodeJSON($blevel,$stateOnoff,$sat,$rgb,$effect,$speed);
    return "$name|$response_encode";
}

sub PlayBulbCandle_gattCharWrite($$$$$$$$$) {

    my ($sat,$rgb,$effect,$speed,$stateEffect,$stateOnoff,$mac,$ac,$ae)  = @_;
    
    my $loop = 0;
    while ( (qx(ps ax | grep -v grep | grep "gatttool -b $mac") and $loop = 0) or (qx(ps ax | grep -v grep | grep "gatttool -b $mac") and $loop < 5) ) {
        printf "\n(Sub PlayBulbCandle_Run) - gatttool noch aktiv, wait 0.5s for new check\n";
        sleep 0.5;
        $loop++;
    }
    
    
    
    $speed = "01" if( $effect eq "candle" );
    
    if( $stateOnoff == 0 ) {
        qx(gatttool -b $mac --char-write -a $ac -n 00000000);
    } else {
        qx(gatttool -b $mac --char-write -a $ac -n ${sat}${rgb}) if( $stateEffect eq "none" and $effect eq "none" );
        qx(gatttool -b $mac --char-write -a $ae -n ${sat}${rgb}${effects{$effect}}00${speed}00) if( $stateEffect ne "none" or $effect ne "none" );
    }
}

sub PlayBulbCandle_gattCharRead($$$$) {

    my ($mac,$stateEffect,$ac,$ae)       = @_;

    my $loop = 0;
    while ( (qx(ps ax | grep -v grep | grep "gatttool -b $mac") and $loop = 0) or (qx(ps ax | grep -v grep | grep "gatttool -b $mac") and $loop < 5) ) {
        printf "\n(Sub PlayBulbCandle_Run) - gatttool noch aktiv, wait 0.5s for new check\n";
        sleep 0.5;
        $loop++;
    }
    
    my @cc          = split(": ",qx(gatttool -b $mac --char-read -a $ac));
    my @ec          = split(": ",qx(gatttool -b $mac --char-read -a $ae));
    
    my $cc          = join("",split(" ",$cc[1]));
    my $ec          = substr(join("",split(" ",$ec[1])),0,8);

    my $sat            = hex("0x".substr(join("",split(" ",$ec[1])),0,2));
    my $rgb            = substr(join("",split(" ",$ec[1])),2,6);
    my $effect         = $effectsHex{substr(join("",split(" ",$ec[1])),8,2)};
    my $speed          = hex("0x".substr(join("",split(" ",$ec[1])),12,2));


    if( $effect eq "none" ) {
        $sat            = hex("0x".substr(join("",split(" ",$cc[1])),0,2));
        $rgb            = substr(join("",split(" ",$cc[1])),2,6);
    }
    
    return ($ec,$cc,$sat,$rgb,$effect,$speed);
}

sub PlayBulbCandle_readBattery($) {

    my ($mac)   = @_;
    
    chomp(my @blevel  = split(": ",qx(gatttool -b $mac --char-read -a 0x1f)));
    $blevel[1] =~ s/[ \t][ \t]*//g;
    
    return hex($blevel[1]);
}

sub PlayBulbCandle_stateOnOff($$) {

    my ($cc,$ec)    = @_;
    my $state;
    
    if( $cc eq "00000000" and $ec eq "00000000" ) {
        $state = "0";
    } else {
        $state = "1";
    }
    
    return $state;
}

sub PlayBulbCandle_forRun_encodeJSON($$$$$$$$$) {

    my ($mac,$stateOnoff,$sat,$rgb,$effect,$speed,$stateEffect,$ac,$ae) = @_;

    my %data = (
        'mac'           => $mac,
        'stateOnoff'    => $stateOnoff,
        'sat'           => $sat,
        'rgb'           => $rgb,
        'effect'        => $effect,
        'speed'         => $speed,
        'stateEffect'   => $stateEffect,
        'ac'            => $ac,
        'ae'            => $ae
    );
    
    return encode_json \%data;
}

sub PlayBulbCandle_forDone_encodeJSON($$$$$$) {

    my ($blevel,$stateOnoff,$sat,$rgb,$effect,$speed)        = @_;

    my %response = (
        'blevel'     => $blevel,
        'stateOnoff' => $stateOnoff,
        'sat'        => $sat,
        'rgb'        => $rgb,
        'effect'     => $effect,
        'speed'      => $speed
    );
    
    return encode_json \%response;
}

sub PlayBulbCandle_Done($) {

    my ($string) = @_;
    my ($name,$response)       = split("\\|",$string);
    my $hash    = $defs{$name};
    my $state;
    my $color;
    
    
    
    delete($hash->{helper}{RUNNING_PID});
    
    Log3 $name, 3, "(Sub PlayBulbCandle_Done - $name) - Der Helper ist diabled. Daher wird hier abgebrochen" if($hash->{helper}{DISABLED});
    return if($hash->{helper}{DISABLED});
    
    
    
    my $response_json = decode_json($response);
    
    
    if( $response_json->{stateOnoff} == 1 ) { $state = "on" } else { $state = "off" };
    if( $response_json->{sat} eq "255" and $response_json->{rgb} eq "000000" ) {
        $color = "off"; } else { $color = "on"; }
    
    
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "color", "$color");
    readingsBulkUpdate($hash, "battery", $response_json->{blevel});
    readingsBulkUpdate($hash, "onoff", $response_json->{stateOnoff});
    readingsBulkUpdate($hash, "sat", $response_json->{sat}) if( $response_json->{stateOnoff} != 0 and $color ne "off" );
    readingsBulkUpdate($hash, "rgb", $response_json->{rgb}) if( $response_json->{stateOnoff} != 0 and $color ne "off" );
    readingsBulkUpdate($hash, "effect", $response_json->{effect});
    readingsBulkUpdate($hash, "speed", $response_json->{speed});
    readingsBulkUpdate($hash, "state", $state);
    readingsEndUpdate($hash,1);

    $hash->{helper}{onoff}  = $response_json->{stateOnoff};
    $hash->{helper}{sat}    = $response_json->{sat} if( $response_json->{stateOnoff} != 0 and $color ne "off" );
    $hash->{helper}{rgb}    = $response_json->{rgb} if( $response_json->{stateOnoff} != 0 and $color ne "off" );
    $hash->{helper}{effect} = $response_json->{effect};
    $hash->{helper}{speed}  = $response_json->{speed};
    
    
    Log3 $name, 4, "(Sub PlayBulbCandle_Done - $name) - Abschluss!";
}

sub PlayBulbCandle_Aborted($) {

    my ($hash) = @_;
    my $name = $hash->{NAME};

    delete($hash->{helper}{RUNNING_PID});
    Log3 $name, 3, "($name) - The BlockingCall Process terminated unexpectedly. Timedout";
}











1;








=pod
=item device
=item summary    
=item summary_DE 

=begin html

=end html

=begin html_DE

=end html_DE

=cut