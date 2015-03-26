#eggdrop1.6 +/-
#
# Buttbot port to eggdrop tcl
#
# Contributed by Gar (mkgarvin) <gar@comrade.us>
#
##########################################################################

#@##### SETUP THE SCRIPT #######
# Please change the details below

#Make sure hyphen.tex exists, it is part of the main buttbot repo
package require textutil
textutil::adjust::readPatterns "/home/lame/hyphen.tex"

# Channel(s) you want your bot to buttify
set channel "#lamechan"

# People who get buttified more often
set friends "lamedude lamerguy"

# How often to buttify friends
set friendfreq 20

# People who don't get buttified
set enemies ""

# How often to buttify everyone else
set normalfreq 51

# Whether or not to log buttify activity, set to 1 to enable
set logbutts 0

#change this if you really have to
set stopwords {
 {a}
 {about}
 {above}
 {absent}
 {across}
 {after}
 {against}
 {all}
 {along}
 {among}
 {an}
 {and}
 {are}
 {around}
 {as}
 {at}
 {atop}
 {be}
 {before}
 {behind}
 {below}
 {beneath}
 {beside}
 {besides}
 {between}
 {beyond}
 {but}
 {by}
 {can}
 {could}
 {do}
 {down}
 {during}
 {each}
 {except}
 {for}
 {from}
 {had}
 {has}
 {have}
 {he}
 {he'll}
 {her}
 {him}
 {his}
 {how}
 {I}
 {I'm}
 {if}
 {in}
 {inside}
 {into}
 {is}
 {it}
 {it's}
 {like}
 {many}
 {might}
 {must}
 {near}
 {next}
 {not}
 {of}
 {off}
 {on}
 {one}
 {onto}
 {opposite}
 {or}
 {other}
 {out}
 {outside}
 {over}
 {past}
 {per}
 {plus}
 {round}
 {said}
 {she}
 {should}
 {since}
 {so}
 {some}
 {than}
 {that}
 {the}
 {their}
 {them}
 {then}
 {there}
 {these}
 {they}
 {they'll}
 {they're}
 {this}
 {through}
 {till}
 {times}
 {to}
 {toward}
 {towards}
 {under}
 {unlike}
 {until}
 {up}
 {upon}
 {via}
 {was}
 {we}
 {we'll}
 {we're}
 {were}
 {what}
 {when}
 {which}
 {will}
 {with}
 {within}
 {without}
 {word}
 {won't}
 {worth}
 {would}
 {you}
 {you'll}
 {you're}
 {your}
}

#####################################################
### don't need to touch the stuff below this line ###
#$###################################################


bind pubm - * checkbutt

#this isn't *quite* like Tex->Hyphenate but it's as close as tcl does afaik
proc hyphenate {word} {
    if {[catch {
            set h [textutil::adjust::adjust $word -hyphenate true -strictlength true -length [string length $word]]
        } excuse]} {
            set h $word
    } else {
        set h [textutil::adjust::adjust $word -hyphenate true -strictlength true -length [string length $word]]
    }
    return $h
}

#random weighted string sort, after a fashion
proc rwssort {a b} {
    if {[rand [string length $a]] > [rand [string length $b]]} {
        return -1
    } else {
        return 1
    }
}

proc tobuttornottobutt {nick} {
    global friends enemies friendfreq normalfreq
    if {[lsearch -exact $enemies $nick] != -1} {
        return 1
    } elseif {[lsearch -exact $friends $nick] != -1} {
        return [rand $friendfreq]
    } else {
        return [rand $normalfreq]
    }
}

proc buttsub {candidate} {
    set h [hyphenate $candidate]
    set umatched ""
    if {[llength $h] > 1} {
        set firstsyllable [lindex $h 0]
        regexp {^[A-Z]} $firstsyllable umatched
        if {[string toupper $firstsyllable] == $firstsyllable} {
            set h [lreplace $h 0 0 "BUTT"]
        } elseif {$umatched != ""} {
            set h [lreplace $h 0 0 "Butt"]
        } else {
            set h [lreplace $h 0 0 "butt"]
        }
        set h [join $h ""]
    } else {
        set smatched ""
        regexp {'?s$} $h smatched
        regexp {^[A-Z]} $h umatched
        if {[string toupper $h] == $h} {
            set h "BUTT"
        } elseif {$umatched != ""} {
            set h "Butt"
        } else {
            set h "butt"
        }
        if {$smatched == "s"} {
            append h "s"
        } elseif {$smatched == "'s"} {
            append h "'s"
        }
    }
    return $h
}

proc buttify {text chan} {
    global stopwords logbutts
    set words [split $text " "]
    set repetitions [expr [llength $text] / 11]
    set longest [lsort -unique -command rwssort $words]

    foreach word $stopwords {
        set longest [lsearch -all -inline -not -exact $longest $word]
    }

    if {[llength $longest] > $repetitions} {
        set longest [lrange $longest 0 $repetitions]
    }

    foreach candidate $longest {
        set buttword [buttsub $candidate]
        if {$buttword != $candidate} {
            set i [lsearch $words $candidate]
            foreach j $i {
                set words [lreplace $words $j $j $buttword]
            }
        }
    }
    set buttspeak [join $words " "]
    if {$buttspeak != $text} {
        if {$logbutts == 1} { putlog "buttified: $buttspeak" }
        putserv "PRIVMSG $chan :$buttspeak"
    }
}

proc checkbutt {nick host hand chan text} {
    global botnick channel logbutts
    #make sure we're in the right channel and this isn't us talking and we should be buttifying
    if {[lsearch -exact $channel $chan] == -1 || $nick == $botnick || [tobuttornottobutt $nick] != 0} {
        return 0
    } elseif {[llength $text] > 1} {
        if {$logbutts == 1} { putlog "buttifying: $text" }
        utimer [expr [llength [split $text]]*0.2+1] [list buttify $text $chan]
        return 0
    }
}

putlog "buttbot loaded. Ready to buttify, maam."
