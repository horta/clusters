#!/usr/bin/env bash

hosts="yoda-login ebi-login"
declare -a progs=('ls' 'type brew' 'conda --version' 'vim --version' 'nvim --version'
'samtools --help' 'wget --version' 'curl --version' 'emacs --version' 'plink --version'
'plink2 --version; [ $? == 9 ]' 'conda --version' 'cmake --version' 'fish --help'
'zsh --version' 'pbzip2 --version' 'python --version' 'vcftools --help'
'htop --version' 'tar --version' 'gcc --version' 'hg --version' 'git --version'
'glances --version' 'bowtie2 --version' 'bedtools --version' 'qctool -help')

any_err=0

function set_logfile
{
    fix=$1
    if logfile=$(mktemp --suffix=$fix.log 2>/dev/null); then
        return 0
    fi

    if logfile=$(mktemp -t $fix.log); then
        return 0
    fi

    error "Could not create a log file."
    exit 1
}
set_logfile clusters

exec 3> "$logfile"

function cleanup
{
    exec 3>&-

    if [ $any_err -ne 0 ]
    then
        echo "Output stored into <$logfile>"
        return 1
    else
        rm $logfile >/dev/null 2>&1 || true
    fi
    return 0
}
trap cleanup EXIT

function ctrl_c()
{
    echo "exitting..."
    exit 1
}
trap ctrl_c INT

function ok
{
    echo -e "\e[32mOK\e[0m."
}

function fail
{
    any_err=1
    echo -e "\e[31mFAILED\e[0m."
}

for host in $hosts; do
    echo "$host: "

    rpath=$(ssh $host 'echo $PATH' 2>&3)
    IFS=':' read -r -a rpath <<< "$rpath"
    echo "PATH: "
    echo -n "  ${rpath[0]} " && [[ ${rpath[0]} == */condabin ]] && ok || fail
    echo -n "  ${rpath[1]} " && [[ ${rpath[1]} == */go/bin ]] && ok || fail
    echo -n "  ${rpath[2]} " && [[ ${rpath[2]} == *system/bin ]] && ok || fail
    echo -n "  ${rpath[3]} " && [[ ${rpath[3]} == */.linuxbrew/sbin ]] && ok || fail

    echo "$host:" >&3
    for prog in "${progs[@]}"
    do
        name=$(echo $prog | head -n1 | awk '{print $1;}')
        echo -n "Testing $name... "
        echo "Testing $name... " >&3
        if ssh $host "$prog" >/dev/null 2>&3
        then
            ok
        else
            fail
        fi
    done
done
