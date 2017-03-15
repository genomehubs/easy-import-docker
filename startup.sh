#!/bin/bash
# ./auto_import.sh -s -g -d heliconius_melpomene_hmel2_core_31_84_1

EIDIR=/ensembl/easy-import
DOWNLOADDIR=/import/download
BLASTDIR=/import/blast
CONFDIR=/import/conf
DATADIR=/import/data
IMPORTSEQ=0
PREPAREGFF=0
IMPORTGENE=0
VERIFY=0
IMPORTBLAST=0
IMPORTRM=0
IMPORTCEG=0
EXPORTJSON=0
EXPORTSEQ=0
EXPORTFEATURES=0
INDEX=0
DEFAULTINI="$CONFDIR/default.ini"
OVERINI="$CONFDIR/overwrite.ini"

while getopts "spgvbrcjefid:o:" OPTION
do
  case $OPTION in
    s)  IMPORTSEQ=1;;      # import_sequences.pl
    p)  PREPAREGFF=1;;     # prepare_gff.pl
    g)  IMPORTGENE=1;;     # import_gene_models.pl
    v)  VERIFY=1;;         # verify_translations.pl
    b)  IMPORTBLAST=1;;    # import_blastp.pl; import_interproscan.pl
    r)  IMPORTRM=1;;       # import_repeatmasker.pl
    c)  IMPORTCEG=1;;      # import_cegma_busco.pl
    e)  EXPORTSEQ=1;;      # export_sequences.pl
    j)  EXPORTJSON=1;;     # export_json.pl
    f)  EXPORTFEATURES=1;; # export_features.pl
    i)  INDEX=1;;          # index_database.pl
    d)  DATABASE=$OPTARG;; # core database name
  esac
done

# check database has been specified
if [ -z ${DATABASE+x} ]; then
  echo "ERROR: database variable (-e DATABASE=dbname) has not been set"
  exit
fi

if ! [ -d $DATABASE ]; then
  mkdir -p $DATABASE
fi

cd $DATABASE

if ! [ -d log ]; then
  mkdir -p log
fi

# check if $DEFAULTINI file exists
if ! [ -s $DEFAULTINI ]; then
  DEFAULTINI=
fi

# check if $OVERINI file exists
if ! [ -s $OVERINI ]; then
  OVERINI=
fi

if ! [ -z $INI ]; then
  OVERINI="$CONFDIR/$INI $OVERINI"
fi

# check main ini file exists
if ! [ -s $CONFDIR/$DATABASE.ini ]; then
  perl $EIDIR/core/generate_conf_ini.pl $DATABASE $DEFAULTINI $OVERINI
fi
DBINI=$CONFDIR/$DATABASE.ini
DISPLAY_NAME=$(awk -F "=" '/SPECIES.DISPLAY_NAME/ {print $2}' $DBINI | perl -pe 's/^\s*// and s/\s*$// and s/\s/_/g')
ASSEMBLY=${DISPLAY_NAME}_$(awk -F "=" '/ASSEMBLY.DEFAULT/ {print $2}' $DBINI | perl -pe 's/^\s*// and s/\s*$// and s/\s/_/g')

if ! [ $IMPORTSEQ -eq 0 ]; then
  echo "importing sequences"
  perl $EIDIR/core/import_sequences.pl $DEFAULTINI $DBINI $OVERINI &> >(tee log/import_sequences.err)
fi

if ! [ $PREPAREGFF -eq 0 ]; then
  echo "preparing gff"
  perl $EIDIR/core/prepare_gff.pl $DEFAULTINI $DBINI $OVERINI &> >(tee log/prepare_gff.err)
fi

if ! [ $IMPORTGENE -eq 0 ]; then
  echo "importing gene models"
  perl $EIDIR/core/import_gene_models.pl $DEFAULTINI $DBINI $OVERINI &> >(tee log/import_gene_models.err)
fi

if ! [ $VERIFY -eq 0 ]; then
  echo "verifying import"
  perl $EIDIR/core/verify_translations.pl $DEFAULTINI $DBINI $OVERINI &> >(tee log/verify_translations.err)
  cat summary/verify_translations.log >> log/verify_translations.err
fi

if ! [ $IMPORTBLAST -eq 0 ]; then
  echo "importing blastp/interproscan"
  BLASTPINI="$CONFDIR/$DATABASE.blastpinterproscan.ini"
  if ! [ -s $BLASTPINI ]; then
    # create ini file to fetch result files from download directory
    printf "[FILES]
  BLASTP = [ BLASTP $DOWNLOADDIR/blastp/${ASSEMBLY}.proteins.fa.blastp.uniprot_sprot.1e-10.tsv.gz ]
  IPRSCAN = [ IPRSCAN $DOWNLOADDIR/interproscan/${ASSEMBLY}.proteins.fa.interproscan.tsv.gz ]
[XREF]
  BLASTP = [ 2000 Uniprot/swissprot/TrEMBL UniProtKB/TrEMBL ]\n" > $BLASTPINI
  fi
  perl $EIDIR/core/import_blastp.pl $DEFAULTINI $DBINI $BLASTPINI $OVERINI &> >(tee log/import_blastp.err)
  perl $EIDIR/core/import_interproscan.pl $DEFAULTINI $DBINI $BLASTPINI $OVERINI &> >(tee log/import_interproscan.err)
fi

if ! [ $IMPORTRM -eq 0 ]; then
  echo "importing repeatmasker"
  RMINI="$CONFDIR/$DATABASE.repeatmasker.ini"
  if ! [ -s $RMINI ]; then
    # create ini file to fetch result files from download directory
    printf "[FILES]\n  REPEATMASKER = [ txt $DOWNLOADDIR/repeats/${ASSEMBLY}.scaffolds.fa.repeatmasker.out.gz ]\n" > $RMINI
  fi
  perl $EIDIR/core/import_repeatmasker.pl $DEFAULTINI $DBINI $RMINI $OVERINI &> >(tee log/import_repeatmasker.err)
fi

if ! [ $IMPORTCEG -eq 0 ]; then
  echo "importing cegma/busco"
  CEGINI="$CONFDIR/$DATABASE.cegmabusco.ini"
  if ! [ -s $CEGINI ]; then
    # create ini file to fetch result files from download directory
    printf "[FILES]
  CEGMA = [ txt $DOWNLOADDIR/cegma/${ASSEMBLY}.scaffolds.fa.cegma.completeness_report.txt ]
  BUSCO = [ txt $DOWNLOADDIR/busco/${ASSEMBLY}.scaffolds.fa.busco.short_summary.txt ]\n" > $CEGINI
  fi
  perl $EIDIR/core/import_cegma_busco.pl $DEFAULTINI $DBINI $CEGINI $OVERINI &> >(tee log/import_cegma_busco.err)
fi

if ! [ $EXPORTSEQ -eq 0 ]; then
  echo "exporting sequences"
  if ! [ -d $DOWNLOADDIR/sequence ]; then
    mkdir -p $DOWNLOADDIR/sequence
  fi
  perl $EIDIR/core/export_sequences.pl $DEFAULTINI $DBINI $OVERINI &> >(tee log/export_sequences.err)
  cd exported
  LIST=`ls ${ASSEMBLY}.{scaffolds,cds,proteins}.fa`
  echo "$LIST"
  cd ../
  cp exported/${ASSEMBLY}.scaffolds.fa $BLASTDIR
  if [ -s exported/${ASSEMBLY}.cds.fa ]; then
    cp exported/${ASSEMBLY}.cds.fa $BLASTDIR
  fi
  if [ -s exported/${ASSEMBLY}.proteins.fa ]; then
    cp exported/${ASSEMBLY}.proteins.fa $BLASTDIR
  fi
  echo "$LIST" | parallel perl -p -i -e '"s/^>(\S+)\s(\S+)\s(\S+)/>\${2}__\${3}__\$1/"' $BLASTDIR/{}
  rename "s/.scaffolds./_scaffolds./; s/.cds./_cds./; s/.proteins./_proteins./" $BLASTDIR/*.{scaffolds,cds,proteins}.fa
  gzip exported/*.fa
  mv exported/*.gz $DOWNLOADDIR/sequence/
#  rm -rf exported
fi

if ! [ $EXPORTJSON -eq 0 ]; then
  echo "exporting json"
  if ! [ -d $DOWNLOADDIR/json ]; then
    mkdir -p $DOWNLOADDIR/json
    mkdir -p $DOWNLOADDIR/json/annotations
    mkdir -p $DOWNLOADDIR/json/assemblies
    mkdir -p $DOWNLOADDIR/json/meta
  fi
  perl $EIDIR/core/export_json.pl $DEFAULTINI $DBINI $OVERINI &> >(tee log/export_json.err)
  echo "done"
  mv web/*.codon-usage.json $DOWNLOADDIR/json/annotations
  mv web/*.assembly-stats.json $DOWNLOADDIR/json/assemblies
  mv web/*.meta.json $DOWNLOADDIR/json/meta
  rm -rf web
fi

if ! [ $EXPORTFEATURES -eq 0 ]; then
  echo "exporting embl"
  if ! [ -d $DOWNLOADDIR/embl ]; then
    mkdir -p $DOWNLOADDIR/embl
  fi
  perl $EIDIR/core/export_features.pl $DEFAULTINI $DBINI $OVERINI &> >(tee log/export_features.err)
  gzip exported/*.embl
  mv exported/*.gz $DOWNLOADDIR/embl/
  rm -rf exported
  echo "done"
fi

if ! [ $INDEX -eq 0 ]; then
  echo "indexing database"
  perl $EIDIR/core/index_database.pl $DEFAULTINI $DBINI $OVERINI &> >(tee log/index_database.err)
fi

cd ../
