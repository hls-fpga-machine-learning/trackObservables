#!/bin/bash

if [[ "$1" == "" ]]; then
    echo "*****************************************"
    echo "*                                       *"
    echo "* Track Observables Study: Steer Script *"
    echo "*                                       *"
    echo "*****************************************"
    echo "* MAKE   - build executable             *"
    echo "* JOBS   - launch condor jobs           *"
    echo "* MERGE  - merge outputs from EOS       *"
    echo "* PLOT   - plot output                  *"
    echo "* WWW    - send plots to CERNWEB        *"
    echo "* TRAIN  - run BDT trainings            *"
    echo "* BDTS_MOVE - move BDT trainings        *"
    echo "* BDTS_PLOT - plot BDT results          *"
    echo "* BDTS_WWW  - send BDT plots to CERNWEB *"
    echo "*****************************************"
    echo ""
    
    exit 1
fi

cd processing
procdir=$PWD

anasubs=(r0_h0_e0 
r05_h05_e005 
r05_h01_e005 
r05_h01_e005_t 
r05_h002_e005_t)

anacfgs=(z r0.5:h0.05:e0.005 
r0.5:h0.01:e0.005
r0.5:h0.01:e0.005:t
r0.5:h0.002:e0.005:t)

filehandles=(
processed-pythia82-fcc100-WW-pt5-50k 
processed-pythia82-lhc13-WW-pt1-50k 
processed-pythia82-fcc100-ZZ-pt5-50k 
processed-pythia82-lhc13-ZZ-pt1-50k 
processed-pythia82-fcc100-gg-pt5-50k 
processed-pythia82-lhc13-gg-pt1-50k 
processed-pythia82-fcc100-tt-pt5-50k 
processed-pythia82-lhc13-tt-pt1-50k 
processed-pythia82-fcc100-qq-pt5-50k 
processed-pythia82-lhc13-qq-pt1-50k)

trainings=(
shapesonly
massonly
all)



####################################################################
#             Nothing should change below this line                #
####################################################################


case $1 in

MAKE )
############################# MAKE #################################
echo "Making executables"

make
eval `eos root://cmseos.fnal.gov rm /store/user/${USER}/TrackObservablesStudy/anaSubstructure`
xrdcp anaSubstructure root://cmseos.fnal.gov:///store/user/${USER}/TrackObservablesStudy/

;;

JOBS)
############################# JOBS #################################
echo "Running jobs"

i=0
for ana in ${anasubs[*]} ; do
    # create output directory, if it does not exist
    eval `eos root://cmseos.fnal.gov mkdir /store/user/${USER}/${ana}`

    # remove existing output files from EOS directory 
    for tfile in $(xrdfs root://cmseos.fnal.gov ls -u /store/user/${USER}/${ana}); do
        filehandle=(${tfile//\// })
        roothandle=${filehandle[${#filehandle[@]}-1]}
        eval `eos root://cmseos.fnal.gov rm /store/user/${USER}/${ana}/${roothandle}`
    done

    # remove output log files
    rm ./${ana}/*

    # submit condor jobs
    python SubmitCondor.py --indir /store/user/${USER}/TrackObservablesStudy/fromMarat/ \
        --outdir ./${ana}/ \
        --maxEvents 50000 \
        --evPerJob 10000 \
        --anaSubLoc root://cmseos.fnal.gov:///store/user/${USER}/TrackObservablesStudy/anaSubstructure \
        --outdirname ${ana} \
        --cfg ${anacfgs[i]}

    let "i += 1"
done

;;

MERGE )
############################# MERGE #################################
echo "Merging outputs"
cd /uscms_data/d3/${USER}/CMSSW_8_0_4/src/ 
source /cvmfs/cms.cern.ch/cmsset_default.sh
eval `scramv1 runtime -sh`

cd /uscms_data/d3/${USER}/TrackObservablesStudy/trackObservables/processing/

for ana in ${anasubs[*]} ; do
for fileh in ${filehandles[*]} ; do
    echo " "
    echo " "
    echo " "
    echo "Working on ${fileh}-${ana}.root"
    echo " "
    hadd ${fileh}-${ana}.root  \
        `xrdfs root://cmseos.fnal.gov ls -u /store/user/${USER}/${ana} | grep root | grep ${fileh}`
done
done

;;


PLOT )
############################## PLOT #################################

cd /uscms_data/d3/${USER}/CMSSW_8_0_4/src/ 
source /cvmfs/cms.cern.ch/cmsset_default.sh
eval `scramv1 runtime -sh`

cd ${procdir}/../plotting/

mkdir plots
for ana in ${anasubs[*]} ; do
    mkdir plots/${ana}
    rm plots/${ana}/*
    
    cmd=""
for fileh in ${filehandles[*]} ; do
    echo " "
    echo " "
    echo " "
    echo "Working on ${fileh}-${ana}.root"
    echo " "

    cmd="${cmd} && python quickPlotter.py -b --basedir ../processing"
    cmd="${cmd} --basedir ../processing"
    cmd="${cmd} --ana ${ana}"
    cmd="${cmd} -o ./plots/${ana}/ > ${fileh}-${ana}.out"
done

    nohup sh -c "eval ${cmd}" &
done


;;

WWW )
############################### WWW #################################
echo "Sending plots to your www directory on LXPLUS"

cd ${procdir}/../plotting/

if [[ "$2" == "" ]]; then
    echo ""
    echo "WWW requires a second argument for the target directory in your www area."
    echo " - format: ~/www/TrackObservablesStudy/SmearPlots/\$2/"
    exit 1;
fi

for ana in ${anasubs[*]} ; do
    scp plots/${ana}/* \
        ${USER}@lxplus.cern.ch:~/www/TrackObservablesStudy/SmearPlots/$2/${ana}/
done

;;

TRAIN )
############################# TRAIN #################################
echo "Running trainings"

# signal process groups to train (csv)
aloSigList=(WW,ZZ
tt
qq
tt
WW)

# background process groups to train (csv)
aloBkgList=(gg,qq
gg,qq
gg
WW,ZZ
ZZ)

# variables for each group 
massVars="j_mass_trim,j_mass_mmdt,j_mass_prun,j_mass_sdb2,j_mass_sdm1"

aloVarList=("j_c2_b1,j_c2_b2,j_d2_b1,j_d2_b2,j_tau21_b1,j_tau21_b2"
"j_tau32_b1,j_tau32_b2"
"j_c1_b0,j_c1_b1,j_c1_b2,j_tau1_b1,j_tau1_b2,j_zlogz,j_multiplicity"
"j_c2_b1,j_c2_b2,j_d2_b1,j_d2_b2,j_tau21_b1,j_tau21_b2,j_c1_b0,j_c1_b1,j_c1_b2,j_tau1_b1,j_tau1_b2,j_zlogz,j_tau32_b1,j_tau32_b2"
"j_c2_b1,j_c2_b2,j_d2_b1,j_d2_b2,j_tau21_b1,j_tau21_b2,j_c1_b0,j_c1_b1,j_c1_b2,j_tau1_b1,j_tau1_b2,j_zlogz,j_tau32_b1,j_tau32_b2")

shapeVarList=("j_d2_b1,j_d2_b2,j_tau21_b1,j_tau21_b2"
"j_tau32_b1,j_tau32_b2"
"j_tau1_b1,j_tau1_b2,j_zlogz,j_multiplicity"
"j_d2_b1,j_d2_b2,j_tau21_b1,j_tau21_b2,j_tau1_b1,j_tau1_b2,j_zlogz,j_tau32_b1,j_tau32_b2"
"j_d2_b1,j_d2_b2,j_tau21_b1,j_tau21_b2,j_tau1_b1,j_tau1_b2,j_zlogz,j_tau32_b1,j_tau32_b2")

cd ${procdir}/../analysis/
for ana in ${anasubs[*]} ; do
    for training in ${trainings[*]} ; do
        rm ${procdir}/../analysis/trainings_${ana}_${training}/*
    done

    i=0
    for sig in ${aloSigList[*]}; do
        # all trainings
        cmd="sh launchJobs.sh ${ana}_all ${aloSigList[$i]} ${aloBkgList[$i]} ${massVars},${aloVarList[$i]}"
        eval "$cmd"
        cmd="sh launchJobs.sh ${ana}_all ${aloBkgList[$i]} ${aloSigList[$i]} ${massVars},${aloVarList[$i]}"
        eval "$cmd"
        
        # shapesonly trainings
        if [[ "${trainings[@]}" =~ "shapesonly" ]] ; then
            cmd="sh launchJobs.sh ${ana}_shapesonly ${aloSigList[$i]} ${aloBkgList[$i]} ${shapeVarList[$i]}"
            eval "$cmd"
            cmd="sh launchJobs.sh ${ana}_shapesonly ${aloBkgList[$i]} ${aloSigList[$i]} ${shapeVarList[$i]}"
            eval "$cmd"
        fi

        # massonly trainings
        if [[ "${trainings[@]}" =~ "massonly" ]] ; then
            cmd="sh launchJobs.sh ${ana}_massonly ${aloSigList[$i]} ${aloBkgList[$i]} ${massVars}"
            eval "$cmd"
            cmd="sh launchJobs.sh ${ana}_massonly ${aloBkgList[$i]} ${aloSigList[$i]} ${massVars}"
            eval "$cmd"
        fi

        let "i += 1"    
    done
done

;;

BDTS_MOVE )
############################ BDT_MOVE ################################
echo "Moving BDT training files from EOS"
echo ""

for ana in ${anasubs[*]} ; do
for training in ${trainings[*]} ; do
    echo "For ${ana}_${training}:"
    mkdir -p ${procdir}/../output/${ana}/${training}/eosrootfiles
    rm   -rf ${procdir}/../output/${ana}/${training}/eosrootfiles/*
        
    # move existing output files from EOS directory 
    echo " - Moving files..."
    for tfile in $(xrdfs root://cmseos.fnal.gov ls -u /store/user/${USER}/SubROC/trainings_${ana}_${training}); do
        eval `xrdcp ${tfile} ${procdir}/../output/${ana}/${training}/eosrootfiles/` 
    done
    
    # untar files 
    echo " - Untarring files..."
    cd ${procdir}/../output/${ana}/${training}/eosrootfiles
    for tfile in $(ls -u ${procdir}/../output/${ana}/${training}/eosrootfiles/*.gz); do
        tar -xvf ${tfile}
    done

    rm     ${procdir}/../output/${ana}/${training}/eosrootfiles/*.gz
    rm -rf ${procdir}/../output/${ana}/${training}/eosrootfiles/weights
done
done

;;

BDTS_PLOT )
############################ BDT_PLOT ################################
echo "Plotting ROCs and grabbing separation statistics"
echo ""

for ana in ${anasubs[*]} ; do
for training in ${trainings[*]} ; do
    echo " - Plotting for ${ana}"
    cd ${procdir}/../analysis/

    # get separation statisics 
    python getSeparationTXT.py --inputs ./trainings_${ana}_${training}/ --output ${procdir}/../output/${ana}/${training}

    # get ROC plots 
    root -l -b -q "getROCs.cc(\"${procdir}/../output/${ana}/${training}/eosrootfiles/\",\"${procdir}/../output/${ana}/${training}\")"

    # get ROC background rejection grids 
    python getROCBkgRej.py --inputs ${procdir}/../output/${ana}/${training}/eosrootfiles/ --output ${procdir}/../output/${ana}/${training}
    break
done
done

;;

BDTS_WWW )
############################ BDT_WWW ################################
echo "Sending BDT plots to your www directory on LXPLUS"

if [[ "$2" == "" ]]; then
    echo ""
    echo "WWW requires a second argument for the target directory in your www area."
    echo " - format: ~/www/TrackObservablesStudy/SmearPlots/\$2/"
    exit 1;
fi

for ana in ${anasubs[*]} ; do
for training in ${trainings[*]} ; do
    scp ${procdir}/../output/${ana}/${training}/*.{pdf,png,txt}  \
        ${USER}@lxplus.cern.ch:~/www/TrackObservablesStudy/SmearPlots/$2/${ana}/${training}/
done
done

;;
esac