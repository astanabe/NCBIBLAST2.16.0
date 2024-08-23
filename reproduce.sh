# print system information
if test `uname -s` = 'Linux'; then
uname -a
ulimit -a
env
free
lscpu
elif test `uname -s` = 'Darwin'; then
sysctl -a
fi
# set variables
export DIAG_TRACE=1
export DIAG_POST_LEVEL=Trace
# make directory
mkdir reproduce
# change current directory
cd reproduce
# download executable binary
if test `uname -s` = 'Linux'; then
NCPU=`grep -c processor /proc/cpuinfo`
wget -nv -c https://ftp.ncbi.nih.gov/blast/executables/blast+/2.15.0/ncbi-blast-2.15.0+-x64-linux.tar.gz
wget -nv -c https://ftp.ncbi.nih.gov/blast/executables/blast+/2.16.0/ncbi-blast-2.16.0+-x64-linux.tar.gz
elif test `uname -s` = 'Darwin'; then
NCPU=`sysctl -n hw.logicalcpu_max`
curl -sS -O -C - https://ftp.ncbi.nih.gov/blast/executables/blast+/2.15.0/ncbi-blast-2.15.0+-x64-macosx.tar.gz
curl -sS -O -C - https://ftp.ncbi.nih.gov/blast/executables/blast+/2.16.0/ncbi-blast-2.16.0+-x64-macosx.tar.gz
if test `uname -m` = 'arm64'; then
echo 'A' > A.txt
softwareupdate --install-rosetta < A.txt
fi
fi
# download BLAST databases
if test `uname -s` = 'Linux'; then
wget -nv -c https://ftp.ncbi.nih.gov/blast/db/LSU_eukaryote_rRNA.tar.gz
wget -nv -c https://ftp.ncbi.nih.gov/blast/db/SSU_eukaryote_rRNA.tar.gz
elif test `uname -s` = 'Darwin'; then
curl -sS -O -C - https://ftp.ncbi.nih.gov/blast/db/LSU_eukaryote_rRNA.tar.gz
curl -sS -O -C - https://ftp.ncbi.nih.gov/blast/db/SSU_eukaryote_rRNA.tar.gz
fi
# extract
ls *.tar.gz | xargs -P 4 -L 1 tar -xzf
# remove taxdb
rm -f taxdb.* taxonomy4blast.sqlite3

# make testsuperset database
ncbi-blast-2.15.0+/bin/blastdb_aliastool -dbtype nucl -dblist 'LSU_eukaryote_rRNA SSU_eukaryote_rRNA' -out testsuperset -title testsuperset
# make seqidlist of subset
ncbi-blast-2.15.0+/bin/blastdbcmd -db ./testsuperset -dbtype nucl -entry all -outfmt '%i' -out - | head -n 100 > testsubset.txt
# convert seqidlist to bsl
ncbi-blast-2.15.0+/bin/blastdb_aliastool -seqid_dbtype nucl -seqid_db ./testsuperset -seqid_file_in testsubset.txt -seqid_title testsubset -seqid_file_out testsubset.bsl
# make testsubset database
ncbi-blast-2.15.0+/bin/blastdb_aliastool -dbtype nucl -db ./testsuperset -seqidlist testsubset.bsl -out testsubset -title testsubset

# make query file
echo '>q1
CAGCATAGGAGTTAGTATTTCAACATAGAAATTTTAGGGGGACACAACATTCAGACCACAGCAGATGATT
ATTTAAAACATGGAAAAGTACTCATGAGAAAATAATAAGTATTGACTGAATACATAAAACATGCCACATA
CTGGGCTAAGTACTTTACATCCATGATCTTATTTAAATCTCTCATAAACCCCAAGATAAGGGGAGTAGAT
>q2
ATTACAGCAATTTAATCCTCAGACCGCATTCAAGTTTCATCAATTGTCCAGTGAATCCATCACAGTTAAA
GAATCCACTTGAGAATCCTTTGTTGCATTTAGTTGTCAATGATTTTAGTCTTCTGTCTGCAGTGGTTAGT
TTCTCTATCTTTCCTTGACTGTTCTGACTTGGGTGCTTTTGAAGATTACAGGCCAGTTATTTTGTAGAAG
>q3
ATCCAAGGAAGGCAGCAGGCGCGCAAATTACCCACTCCCGACCCGGGGAGGTAGTGACGAAAAATAACAA
TACAGGACTCTTTCGAGGCCCTGTAATTGGAATGAGTCCACTTTAAATCCTTTAACGAGGATCCATTGGA
GGGCAAGTCTGGTGCCAGCAGCCGCGGTAATTCCAGCTCCAATAGCGTATATTAAAGTTGCTGCAGTTAA
>q4
TTCCGGGGGGAGTATGGTTGCAAAGCTGAAACTTAAAGGAATTGACGGAAGGGCACCACCAGGAGTGGAG
CCTGCGGCTTAATTTGACTCAACACGGGAAACCTCACCCGGCCCGGACACGGACAGGATTGACAGATTGA
TAGCTCTTTCTCGATTCCGTGGGTGGTGGTGCATGGCCGTTCTTAGTTGGTGGAGCGATTTGTCTGGTTA' > query.fasta

# test 30 times using blastn 2.15.0+
for n in `seq 1 30`
do echo '
The '$n'-th loop started
'
# run blastn 2.15.0+ (DB:testsuperset, Single thread) No problem
echo 'ncbi-blast-2.15.0+/bin/blastn -db ./testsuperset -query query.fasta -out - -evalue 1 -num_threads 1'
perl -e 'alarm shift; exec @ARGV' 30 ncbi-blast-2.15.0+/bin/blastn -db ./testsuperset -query query.fasta -out - -evalue 1 -num_threads 1 > $n.log || exit $?
# run blastn 2.15.0+ (DB:testsuperset, Multi-thread) No problem
echo 'ncbi-blast-2.15.0+/bin/blastn -db ./testsuperset -query query.fasta -out - -evalue 1 -num_threads '$NCPU
perl -e 'alarm shift; exec @ARGV' 30 ncbi-blast-2.15.0+/bin/blastn -db ./testsuperset -query query.fasta -out - -evalue 1 -num_threads $NCPU > $n.log || exit $?
# run blastn 2.15.0+ (DB:testsubset, Single thread) No problem
echo 'ncbi-blast-2.15.0+/bin/blastn -db ./testsubset -query query.fasta -out - -evalue 1 -num_threads 1'
perl -e 'alarm shift; exec @ARGV' 30 ncbi-blast-2.15.0+/bin/blastn -db ./testsubset -query query.fasta -out - -evalue 1 -num_threads 1 > $n.log || exit $?
# run blastn 2.15.0+ (DB:testsubset, Multi-thread) No problem
echo 'ncbi-blast-2.15.0+/bin/blastn -db ./testsubset -query query.fasta -out - -evalue 1 -num_threads '$NCPU
perl -e 'alarm shift; exec @ARGV' 30 ncbi-blast-2.15.0+/bin/blastn -db ./testsubset -query query.fasta -out - -evalue 1 -num_threads $NCPU > $n.log || exit $?
# output message
echo '
Test passed in '$n'-th loop
'
done

# test 30 times using blastn 2.16.0+
for n in `seq 1 30`
do echo '
The '$n'-th loop started
'
# run blastn 2.16.0+ (DB:testsuperset, Single thread) No problem
echo 'ncbi-blast-2.16.0+/bin/blastn -db ./testsuperset -query query.fasta -out - -evalue 1 -num_threads 1'
perl -e 'alarm shift; exec @ARGV' 30 ncbi-blast-2.16.0+/bin/blastn -db ./testsuperset -query query.fasta -out - -evalue 1 -num_threads 1 > $n.log || exit $?
# run blastn 2.16.0+ (DB:testsuperset, Multi-thread) No problem
echo 'ncbi-blast-2.16.0+/bin/blastn -db ./testsuperset -query query.fasta -out - -evalue 1 -num_threads '$NCPU
perl -e 'alarm shift; exec @ARGV' 30 ncbi-blast-2.16.0+/bin/blastn -db ./testsuperset -query query.fasta -out - -evalue 1 -num_threads $NCPU > $n.log || exit $?
# run blastn 2.16.0+ (DB:testsubset, Single thread) No problem
echo 'ncbi-blast-2.16.0+/bin/blastn -db ./testsubset -query query.fasta -out - -evalue 1 -num_threads 1'
perl -e 'alarm shift; exec @ARGV' 30 ncbi-blast-2.16.0+/bin/blastn -db ./testsubset -query query.fasta -out - -evalue 1 -num_threads 1 > $n.log || exit $?
# run blastn 2.16.0+ (DB:testsubset, Multi-thread) Sometimes hangs up (but not always)
echo 'ncbi-blast-2.16.0+/bin/blastn -db ./testsubset -query query.fasta -out - -evalue 1 -num_threads '$NCPU
perl -e 'alarm shift; exec @ARGV' 30 ncbi-blast-2.16.0+/bin/blastn -db ./testsubset -query query.fasta -out - -evalue 1 -num_threads $NCPU > $n.log || exit $?
# output message
echo '
Test passed in '$n'-th loop
'
done
