#!/usr/local/ensembl/bin/perl

=head1 DESCRIPTION

Looks at a specified func_gen database determines which cell lines need an annotation run and prints out helpful stuff for whoever is running the classification analyses.

=head1 AUTHOR(S)

dkeefe@ebi.ac.uk

=head1 USAGE



=head1 EXAMPLES

=head1 SEE ALSO

mysql -u ensro -P3306 -hens-genomics2 -BN -e"select display_label from regulatory_feature " dk_funcgen_classify_58_ES | tr -d 0 | awk '{print length($1)}' | sort | uniq -c

=head1 CVS

 $Log: not supported by cvs2svn $



=cut


use strict;
use DBI;
use Env;
#use EnsemblMart::MartAdaptor;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Getopt::Std;
use IO::Handle;
use IO::File;
use lib '/nfs/users/nfs_d/dkeefe/src/personal/ensembl-personal/dkeefe/perl/modules/';
use DBSQL::Utils;

use constant  NO_ROWS => '0E0';


my($user, $password, $driver, $host, $port);
my $outfile='';
my $infile='';
my $id_list;
my $sp;
my $verbose = 0;
my @temp_tables;
my $release = 58;

my %opt;

if ($ARGV[0]){
&Getopt::Std::getopts('u:p:s:e:H:h:e:n:N:o:i:P:', \%opt) || die ;
}else{
&help_text; 
}


# get configuration from environment variables
&config; # this may fail but config can be on command line

my $func_db = 'dk_encode_catalog_21_34d';# default, can be overridden by args
&process_arguments;

# hook up with the server
my $dbh = &make_contact($func_db);
my $dbu = DBSQL::Utils->new($dbh);

my @sql;
&execute($dbh,@sql);

#my $cells_ref = $dbh->selectcol_arrayref("select name from cell_type;");
my $reg_sets_aaref = $dbh->selectall_arrayref("select name, feature_set_id from feature_set where  type = 'regulatory' and name like '%:%'");
my @good_sets;

foreach my $set_ref (@$reg_sets_aaref){

    my $label_length = $dbu->get_count("select length(display_label) from regulatory_feature where feature_set_id = ".$set_ref->[1]);

    my $cell;
    if($label_length > 3){
	($cell) = $set_ref->[0] =~ /RegulatoryFeatures:(.*)/;
	push @good_sets,$cell;
    }
    print  $set_ref->[0]." $label_length $cell\n"; #$feature_set_name."\n";
}

print "\n";
foreach my $cell (@good_sets){
    my $work_db =  "dk_funcgen_classify_$release"."_$cell";
    print "create database $work_db;\n";
}

my $common = '';
if($sp eq 'mus_musculus'){$common = '_mouse'}

print "\n Now edit ~/dbs/current".$common."_funcgen to point to $func_db on $host\n";
print "\n and ~/dbs/current".$common."_core to point to latest species_core\n";
print "\n and copy reg_feat_gen_feat_conf.1 to the v$release dir \n\n";



foreach my $cell (@good_sets){
    my $work_db =  "dk_funcgen_classify_$release"."_$cell";
    print "mkdir db$cell\n";
    print "cd db$cell\n";
    print "gen_feats_4_classification.pl -e $work_db -v2 -s $sp > & log1  \n";
    print "reg_feats_4_classification.pl -e $work_db -v2 -c $cell -s $sp > & log2  \n";
    print "mock_reg_feat_gen.pl -e $work_db -i regulatory_features_filtered -o mockreg_features_filtered >& log3 \n";
    print "reg_feat_gen_feat_overlaps.pl -e $work_db -v1 -c ../reg_feat_gen_feat_conf.1 > & log4 &\n";

    print "\n";

}


$dbh->disconnect;
exit;


 
###################################################################

sub backtick{
    my $command = shift;

    warn "executing $command \n" if ($verbose ==2);

    my $res = `$command`;
    if($?){
        warn "failed to execute $command \n";
        warn "output :-\n $res \n";
	die "exit code $?";
    }

    return $res;
}


# uses global array @temp_tables
sub new_temp{

    my $nom = 'temp_'.$$.'_'.scalar(@temp_tables);
    push @temp_tables,$nom;
    return $nom;

}

# uses global array @temp_tables
sub clean_temp{

    my @sql;
    foreach my $table (@temp_tables){
	push @sql,"drop table if exists $table";
    }

    &execute($dbh,@sql) or die;
}


# execute
#
#  Arg [1]   : scalar database handle from DBI module
#  Arg [2]   : array of scalars containing lines of text in the format of SQL statements
#  Function  : submits each element of Arg2 to the $dbh->prepare and 
#              $dbh->execute methods and checks for successful execution. 
#              Returns 0 on failure, 1 on success. Emits error messages 
#              via &err.
#  Returntype: int
#  Exceptions: none
#  Example   : execute($dbh, @array);

sub execute{
    my $dbh = shift;
    my (@array)=@_;

    my $sth;

    &commentary("processing SQL.");

    foreach my $query(@array){
	
    	&commentary(".");

	    unless($sth=$dbh->prepare($query)){
               &err("Error: preparation of statement failed on: $query\n");
               &err("database error message: ".$dbh->errstr."\n");
               return(0);
	    }

        unless($sth->execute){ # returns true on success
            &err("Error: statement execution failed on: $query\n");
            &err("statement handle error message:".$sth->errstr."\n");
            return(0);
	    }
    }

    &commentary("\n");

    return(1);
}


# when using backticks to exec scripts the caller captures STDOUT
# its best therefore to have error on STDOUT and commentary on STDERR
sub commentary{
    print  "$_[0]";
}



sub get_names_from_file{
    my $file=shift;

    open(IN, "< $file") or die "couldn't open list file $file";

    my @ret;
    while( <IN> ){
        chop;
	push  @ret, $_ ;
    }

    my $text_list = join(",",@ret);
    #print $text_list;
    return $text_list;

}


sub config{
 
($user =     $ENV{'ENSMARTUSER'}) or return(0); # ecs1dadmin
($password = $ENV{'ENSMARTPWD'}) or return(0); #
($host   =   $ENV{'ENSMARTHOST'}) or return(0); #localhost
($port =     $ENV{'ENSMARTPORT'}) or return(0); #3360
($driver  =  $ENV{'ENSMARTDRIVER'}) or return(0); #mysql
 
}
   
sub err{
    print STDERR "$_[0]\n";
}
  



sub print_mart_results{
    my $res_aref = shift;
    my $ma; #dummy to avoid undef err

    if( $ma->result_type() eq 'sequence'){
	foreach my $aref (@$res_aref){
	    print $aref->[0]."\n";
	    print $aref->[1]."\n";
	}
    }else{
	foreach my $aref (@$res_aref){
	    foreach my $field (@$aref){
	           ($field)? print $field." ":print "unavailable ";
	    }
	    print "\n";
	}
    }
}


sub make_contact{
    my $db = shift;

    unless($driver && $db && $host && $port && $user){
	&err("DB connection parameters not set");
        exit(1);
    }

    # hook up with the server
    my $dsn = "DBI:$driver:database=$db;host=$host;port=$port;mysql_local_infile=1";
    my $dbh = DBI->connect("$dsn","$user",$password, {RaiseError => 0});
    if ($dbh){
        print STDERR ("connected to $db\n");
    }else{
        &err("failed to connect to database $db");
        exit(1);
 
    }   

            
    return $dbh;
}



sub process_arguments{

    if ( exists $opt{'h'} ){ 
        &help_text;
    }



    if (exists $opt{H}){
        $host = $opt{H}; 
    }

    if (exists $opt{p}){
        $password = $opt{p}; 
    }

    if (exists $opt{P}){
        $port = $opt{P}; 
    }

    if (exists $opt{u}){
        $user = $opt{u}; 
    }

    $sp = 'homo_sapiens';
    if (exists $opt{s}){
        $sp = lc($opt{s});
    }


    if (exists $opt{o}){
        $outfile = $opt{o};
    }  


    if (exists $opt{i}){
        $infile = $opt{i};
    }  


    if (exists $opt{n}){
        $id_list = $opt{n};
    }

    if (exists $opt{N}){
	$infile = $opt{N};
    }

    if  (exists $opt{e}){
        $func_db = $opt{e};
    } 

} 


sub help_text{
    my $msg=shift;

    if ($msg){
      print STDERR "\n".$msg."\n";
    }

    print STDERR <<"END_OF_TEXT";

    reg_feat_class_prep.pl [-h] for help
                  [-e] get regulatory features from this database
                  [-s] <species> eg -smus_musculus, default = homo_sapiens
                  [-H] <host machine> eg ecs2
                  [-u] <database user> 
                  [-p] <mysql password> 
                  [-P] <mysql port> 

                  [-] 
                  [-] 
                  [-] <> 
                  [-] <> 


END_OF_TEXT


    if($msg){
        exit(1);
    }else{
        exit(0);
    }
}
