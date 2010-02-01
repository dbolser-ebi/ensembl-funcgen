#
# Ensembl module for Bio::EnsEMBL::DBSQL::Funcgen::RegulatoryFeatureAdaptor
#
# You may distribute this module under the same terms as Perl itself

=head1 NAME

Bio::EnsEMBL::DBSQL::Funcgen::RegulatoryFeatureAdaptor - A database adaptor for fetching and
storing RegulatoryFeature objects.

=head1 SYNOPSIS

my $afa = $db->get_RegulatoryFeatureAdaptor();

my $features = $afa->fetch_all_by_Slice($slice);

=head1 DESCRIPTION

The RegulatoryFeatureAdaptor is a database adaptor for storing and retrieving
RegulatoryFeature objects.

=head1 AUTHOR

This module was created by Nathan Johnson.

This module is part of the Ensembl project: http://www.ensembl.org/

=head1 CONTACT

Post comments or questions to the Ensembl development list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Funcgen::DBSQL::RegulatoryFeatureAdaptor;

use Bio::EnsEMBL::Utils::Exception qw( throw warning );
use Bio::EnsEMBL::Funcgen::RegulatoryFeature;
use Bio::EnsEMBL::Funcgen::DBSQL::SetFeatureAdaptor;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Funcgen::DBSQL::SetFeatureAdaptor);



=head2 _get_current_FeatureSet

  Example    : my $regf_featureset = $self->_get_current_FeatureSet;
  Description: Convenience method to get and test the current
  Returntype : Bio::EnsEMBL::Funcgen::FeatureSet
  Exceptions : Throws is FeatureSet is not available
  Caller     : general
  Status     : at risk

=cut

sub _get_current_FeatureSet{
  my $self = shift;

  my $fset = $self->db->get_FeatureSetAdaptor->fetch_by_name('RegulatoryFeatures');

  if(! defined $fset){
	warn('Could not retrieve current RegulatoryFeatures FeatureSet');
  }
  
  return $fset;
}


=head2 fetch_by_stable_id

  Arg [1]    : String $stable_id - The stable id of the regulatory feature to retrieve
  Arg [2]    : optional - Bio::EnsEMBL::FeatureSet
  Example    : my $rf = $rf_adaptor->fetch_by_stable_id('ENSR00000309301');
  Description: Retrieves a regulatory feature via its stable id.
  Returntype : Bio::EnsEMBL::Funcgen::RegulatoryFeature
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub fetch_by_stable_id {
  my ($self, $stable_id, $fset) = @_;

  $fset ||= $self->_get_current_FeatureSet; 

  return (defined $fset) ? $self->fetch_all_by_stable_id_FeatureSets($stable_id, $fset)->[0] : undef;
}

=head2 fetch_all_by_stable_id_FeatureSets

  Arg [1]    : String $stable_id - The stable id of the regulatory feature to retrieve
  Arg [2]    : optional list of FeatureSets
  Example    : my $rf = $rf_adaptor->fetch_by_stable_id('ENSR00000309301');
  Description: Retrieves a regulatory feature via its stable id.
  Returntype : Array ref of Bio::EnsEMBL::Funcgen::RegulatoryFeature objects
  Exceptions : throws if no stable ID provided or FeatureSets aren't valid
               warns if not FeatureSets defined
  Caller     : general
  Status     : at risk

=cut

sub fetch_all_by_stable_id_FeatureSets {
  my ($self, $stable_id, @fsets) = @_;

  #Standard implementation exposes logic name as a parameter
  #But it will always be RegulatoryFeature/Build

  throw('Must provide a stable ID') if ! defined $stable_id;

  $stable_id =~ s/ENSR0*|ENSMUSR0*//;


  #Need to test stable_id here as there is a chance that this argument has been omitted and we are dealing with 
  #a feature set object


  $self->bind_param_generic_fetch($stable_id, SQL_INTEGER);
  my $constraint = 'rf.stable_id=?';


  if(@fsets){#Get current
	
	#need to catch empty array an invalid FeatureSets
	if(scalar(@fsets == 0)){
	  warning("You have not specified any FeatureSets to fetch the RegulatoryFeature from, defaulting to all");
	}
	else{

	  #validate FeatureSets
	  map { $self->db->is_stored_and_valid('Bio::EnsEMBL::Funcgen::FeatureSet', $_)} @fsets;
		 
	  if(scalar(@fsets) == 1){
		$constraint .= ' and rf.feature_set_id=?';
		$self->bind_param_generic_fetch($fsets[0]->dbID, SQL_INTEGER);
	  }else{
		#How can we bind param this?
		
		my @bind_slots;

		foreach my $dbid(map $_->dbID, @fsets){
		  push @bind_slots, '?';
		  $self->bind_param_generic_fetch($dbid, SQL_INTEGER);
		}

		$constraint .= ' AND rf.feature_set_id IN ('.join(', ', @bind_slots).')';
	  } 
	}
  }

  return $self->generic_fetch($constraint);
}




=head2 _tables

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns the names and aliases of the tables to use for queries.
  Returntype : List of listrefs of strings
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _tables {
  my $self = shift;
	
  return (
		  [ 'regulatory_feature', 'rf' ],
		  [ 'feature_set', 'fs'],
		  [ 'regulatory_attribute', 'ra'],
		 );
}

=head2 _columns

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns a list of columns to use for queries.
  Returntype : List of strings
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _columns {
  my $self = shift;
  
  return qw(
			rf.regulatory_feature_id rf.seq_region_id
			rf.seq_region_start      rf.seq_region_end
			rf.seq_region_strand     rf.bound_seq_region_start
			rf.bound_seq_region_end  rf.display_label
			rf.feature_type_id       rf.feature_set_id
			rf.stable_id             ra.attribute_feature_id
			ra.attribute_feature_table
	   );
}


=head2 _left_join

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns an additional table joining constraint to use for
			   queries.
  Returntype : List
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _left_join {
  my $self = shift;
	
  return (['regulatory_attribute', 'rf.regulatory_feature_id = ra.regulatory_feature_id']);
}



=head2 _objs_from_sth

  Arg [1]    : DBI statement handle object
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Creates RegulatoryFeature objects from an executed DBI statement
			   handle.
  Returntype : Listref of Bio::EnsEMBL::RegulatoryFeature objects
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _objs_from_sth {
  my ($self, $sth, $mapper, $dest_slice) = @_;

  
  #For EFG this has to use a dest_slice from core/dnaDB whether specified or not.
  #So if it not defined then we need to generate one derived from the species_name and schema_build of the feature we're retrieving.
  # This code is ugly because caching is used to improve speed
  	
  my ($sa, $reg_feat);#, $old_cs_id);
  $sa = ($dest_slice) ? $dest_slice->adaptor->db->get_SliceAdaptor() : $self->db->get_SliceAdaptor();
  #don't really need this if we're using DNADBSliceAdaptor?
  
  #Some of this in now probably overkill as we'll always be using the DNADB as the slice DB
  #Hence it should always be on the same coord system
  my $ft_adaptor = $self->db->get_FeatureTypeAdaptor();
  my $fset_adaptor = $self->db->get_FeatureSetAdaptor();
  my (@features, @reg_attrs, $seq_region_id);
  my (%fset_hash, %slice_hash, %sr_name_hash, %sr_cs_hash, %ftype_hash);
  my $skip_feature = 0;
  
  my %feature_adaptors = (
						  'annotated' => $self->db->get_AnnotatedFeatureAdaptor(),
						  #external?
						 );
  
  my $stable_id_prefix = $self->db->stable_id_prefix;

	
	my (
	    $dbID,                  $efg_seq_region_id,
	    $seq_region_start,      $seq_region_end,
	    $seq_region_strand,     $bound_seq_region_start,
		$bound_seq_region_end,             $display_label,
		$ftype_id,              $fset_id,
		$stable_id,             $attr_id,
		$attr_type
	);

	$sth->bind_columns(
					   \$dbID,                  \$efg_seq_region_id,
					   \$seq_region_start,      \$seq_region_end,
					   \$seq_region_strand,     \$bound_seq_region_start,
					   \$bound_seq_region_end,  \$display_label,
					   \$ftype_id,              \$fset_id,
					   \$stable_id,             \$attr_id,
					   \$attr_type
					  );

	my ($asm_cs, $cmp_cs, $asm_cs_name);
	my ($asm_cs_vers, $cmp_cs_name, $cmp_cs_vers);
  
	if ($mapper) {
		$asm_cs      = $mapper->assembled_CoordSystem();
		$cmp_cs      = $mapper->component_CoordSystem();
		$asm_cs_name = $asm_cs->name();
		$asm_cs_vers = $asm_cs->version();
		$cmp_cs_name = $cmp_cs->name();
		$cmp_cs_vers = $cmp_cs->version();
	  }
	
	my ($dest_slice_start, $dest_slice_end);
	my ($dest_slice_strand, $dest_slice_length, $dest_slice_sr_name);

	if ($dest_slice) {
		$dest_slice_start   = $dest_slice->start();
		$dest_slice_end     = $dest_slice->end();
		$dest_slice_strand  = $dest_slice->strand();
		$dest_slice_length  = $dest_slice->length();
		$dest_slice_sr_name = $dest_slice->seq_region_name();
	}

	
  my $slice;
	
  FEATURE: while ( $sth->fetch() ) {

	  if(! $reg_feat || ($reg_feat->dbID != $dbID)){
	
		if($skip_feature){
		  undef $reg_feat;#so we don't duplicate the push for the feature previous to the skip feature
		  $skip_feature = 0;
		}

		if($reg_feat){
		  
		  $reg_feat->regulatory_attributes(\@reg_attrs);# if @reg_attrs;
		  push @features, $reg_feat;
		  undef @reg_attrs;

		}

		#Hack to get not NUL 0 autoinserted values to work
		$bound_seq_region_start = undef if ! $bound_seq_region_start;
		$bound_seq_region_end   = undef if ! $bound_seq_region_end;


	    #Need to build a slice adaptor cache here?
	    #Would only ever want to do this if we enable mapping between assemblies??
	    #Or if we supported the mapping between cs systems for a given schema_build, which would have to be handled by the core api
	    
		#this should only be done once for each regulatory_feature_id
		
		
		#get core seq_region_id
		$seq_region_id = $self->get_core_seq_region_id($efg_seq_region_id);

		if(! $seq_region_id){
		  warn "Cannot get slice for eFG seq_region_id $efg_seq_region_id\n".
			"The region you are using is not present in the current dna DB";
		  next;
		}

	    #if($old_cs_id && ($old_cs_id+ != $cs_id)){
	    #  throw("More than one coord_system for feature query, need to implement SliceAdaptor hash?");
	    #}
	    #$old_cs_id = $cs_id;
	    #Need to make sure we are restricting calls to Experiment and channel(i.e. the same coord_system_id)
	    
		#Get the FeatureSet object
		$fset_hash{$fset_id} = $fset_adaptor->fetch_by_dbID($fset_id) if(! exists $fset_hash{$fset_id});
		
		
	    # Get the slice object
	    $slice = $slice_hash{'ID:'.$seq_region_id};
	    
	    if (!$slice) {
	      $slice                            = $sa->fetch_by_seq_region_id($seq_region_id);
	      $slice_hash{'ID:'.$seq_region_id} = $slice;
	      $sr_name_hash{$seq_region_id}     = $slice->seq_region_name();
	      $sr_cs_hash{$seq_region_id}       = $slice->coord_system();
	    }
	    
	    my $sr_name = $sr_name_hash{$seq_region_id};
	    my $sr_cs   = $sr_cs_hash{$seq_region_id};
	    
	    # Remap the feature coordinates to another coord system if a mapper was provided
	    if ($mapper) {
	      
	      throw("Not yet implmented mapper, check equals are Funcgen calls too!");
	      
	      ($sr_name, $seq_region_start, $seq_region_end, $seq_region_strand)
			= $mapper->fastmap($sr_name, $seq_region_start, $seq_region_end, $seq_region_strand, $sr_cs);
	
	      # Skip features that map to gaps or coord system boundaries
		  if(! defined $sr_name){
			$skip_feature = 1;
			next FEATURE;
		  }
	      
	      # Get a slice in the coord system we just mapped to
	      if ( $asm_cs == $sr_cs || ( $cmp_cs != $sr_cs && $asm_cs->equals($sr_cs) ) ) {
		$slice = $slice_hash{"NAME:$sr_name:$cmp_cs_name:$cmp_cs_vers"}
		  ||= $sa->fetch_by_region($cmp_cs_name, $sr_name, undef, undef, undef, $cmp_cs_vers);
	      } else {
		$slice = $slice_hash{"NAME:$sr_name:$asm_cs_name:$asm_cs_vers"}
		  ||= $sa->fetch_by_region($asm_cs_name, $sr_name, undef, undef, undef, $asm_cs_vers);
	      }
	    }
	    
	    # If a destination slice was provided convert the coords
	    # If the destination slice starts at 1 and is forward strand, nothing needs doing
	    if ($dest_slice) {

	      unless ($dest_slice_start == 1 && $dest_slice_strand == 1) {
			
			#can remove the if $bound_seq_region_start/end once we have updated all reg feature entries and store API

			if ($dest_slice_strand == 1) {
			  $seq_region_start       = $seq_region_start - $dest_slice_start + 1;
			  $seq_region_end         = $seq_region_end   - $dest_slice_start + 1;

			  #if as we never have a seq_region start of 0;
			  $bound_seq_region_start = $bound_seq_region_start - $dest_slice_start + 1 if $bound_seq_region_start;
			  $bound_seq_region_end   = $bound_seq_region_end   - $dest_slice_start + 1 if $bound_seq_region_end;
			  
			} 
			else {
			  my $tmp_seq_region_start       = $seq_region_start;
			  my $tmp_bound_seq_region_start = $bound_seq_region_start;
			  $seq_region_start        = $dest_slice_end - $seq_region_end       + 1;
			  $seq_region_end          = $dest_slice_end - $tmp_seq_region_start + 1;
			  $bound_seq_region_start  = $dest_slice_end - $bound_seq_region_end + 1 if $bound_seq_region_end;
			  $bound_seq_region_end    = $dest_slice_end - $tmp_bound_seq_region_start + 1 if $bound_seq_region_start;
			  $seq_region_strand      *= -1;
			}
	      }
	      
	      # Throw away features off the end of the requested slice
		  #Do not account for bounds here.
	      if ($seq_region_end < 1 || $seq_region_start > $dest_slice_length
			  || ( $dest_slice_sr_name ne $sr_name )){
			$skip_feature = 1;
			next FEATURE;
		  }
	      
	      $slice = $dest_slice;
	    }
	    

		my ($reg_type, $reg_attrs, $ftype);
	   		
		if(defined $ftype_id){
		  $ftype = $ft_adaptor->fetch_by_dbID($ftype_id);
		}
		
		$reg_feat = Bio::EnsEMBL::Funcgen::RegulatoryFeature->new_fast
		  ({
			'start'          => $seq_region_start,
			'end'            => $seq_region_end,
			'bound_start'    => $bound_seq_region_start,
			'bound_end'      => $bound_seq_region_end,
			'strand'         => $seq_region_strand,
			'slice'          => $slice,
			'analysis'       => $fset_hash{$fset_id}->analysis(),
			'adaptor'        => $self,
			'dbID'           => $dbID,
			'display_label'  => $display_label,
			'feature_set'    => $fset_hash{$fset_id},
			'feature_type'   => $ftype,
			#'regulatory_attributes' => $reg_attrs,
			'stable_id'      => sprintf($stable_id_prefix."%011d", $stable_id),
		   });

	  }
	
  
	  #populate attributes array
	  if(defined $attr_id  && ! $skip_feature){

		#These will all be fetched on their native slice, not necessarily the slice we have fetched this
		#reg feature on, hence we need to map the features to the current slice
		#otherwise the bounds may get messed up

		my $attr = $feature_adaptors{$attr_type}->fetch_by_dbID($attr_id);

		#now need to reset start and ends for the current slice
		#This is not redefining the slice, so we may get minus start values
		#grab the seq_region_start/ends here first
		#as resetting directly causes problems
		my $attr_sr_start = $attr->seq_region_start;
		my $attr_sr_end = $attr->seq_region_end;
 		$attr->slice($slice);

		if($slice->strand ==1){
		  $attr->start($attr_sr_start - $slice->start +1);
		  $attr->end($attr_sr_end - $slice->start +1);	
		}else{
		  $attr->start($slice->end - $attr_sr_end +1);
		  $attr->end($slice->end - $attr_sr_start +1);	
		}
		
		push @reg_attrs, $attr;
	  }
	}

  #handle last record
  if($reg_feat){
	$reg_feat->regulatory_attributes(\@reg_attrs);# if(@reg_attrs);
	push @features, $reg_feat;
  }
  

  return \@features;
}



=head2 store

  Args       : List of Bio::EnsEMBL::Funcgen::RegulatoryFeature objects
  Example    : $ofa->store(@features);
  Description: Stores given RegulatoryFeature objects in the database. Should only
               be called once per feature because no checks are made for
			   duplicates. Sets dbID and adaptor on the objects that it stores.
  Returntype : Listref of stored RegulatoryFeatures
  Exceptions : Throws if a list of RegulatoryFeature objects is not provided or if
               the Analysis, CellType and FeatureType objects are not attached or stored.
               Throws if analysis of set and feature do not match
               Warns if RegulatoryFeature already stored in DB and skips store.
  Caller     : General
  Status     : At Risk

=cut

sub store{
  my ($self, @rfs) = @_;
	
  if (scalar(@rfs) == 0) {
	throw('Must call store with a list of RegulatoryFeature objects');
  }

  my $sth = $self->prepare("
		INSERT INTO regulatory_feature (
			seq_region_id,         seq_region_start,
			seq_region_end,        bound_seq_region_start,
			bound_seq_region_end,  seq_region_strand,
            display_label,         feature_type_id,
            feature_set_id,        stable_id
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
  
  my $sth2 = $self->prepare("
		INSERT INTO regulatory_attribute (
              regulatory_feature_id, attribute_feature_id, attribute_feature_table
		) VALUES (?, ?, ?)");
  
  my $db = $self->db();
  
  foreach my $rf (@rfs) {
	
	if( ! ref $rf || ! $rf->isa('Bio::EnsEMBL::Funcgen::RegulatoryFeature') ) {
	  throw('Feature must be an RegulatoryFeature object');
	}
	
	if ( $rf->is_stored($db) ) {
	  #does not accomodate adding Feature to >1 feature_set
	  warning('RegulatoryFeature [' . $rf->dbID() . '] is already stored in the database');
	  next;
	}
	
	#Have to do this for Analysis separately due to inheritance
	if ( ! $rf->analysis->is_stored($db)) {
	  throw('A stored Bio::EnsEMBL::Analysis must be attached to the RegulatoryFeature objects to be stored.');
	}
	
	if (! $rf->feature_set->is_stored($db)) {
	  throw('A stored Bio::EnsEMBL::Funcgen::FeatureSet must be attached to the RegulatoryFeature objects to be stored.');
	}
	
	if (! $rf->feature_type->is_stored($db)) {
	  throw('A stored Bio::EnsEMBL::Funcgen::FeatureType must be attached to the RegulatoryFeature objects to be stored.');
	}
	  


	#sanity check analysis matches feature_set analysis
	if($rf->analysis->dbID() != $rf->feature_set->analysis->dbID()){
	  throw("RegulatoryFeature analysis(".$rf->analysis->logic_name().") does not match FeatureSet analysis(".$rf->feature_set->analysis->logic_name().")\n".
			"Cannot store mixed analysis sets");
	}

	#Complex analysis to be stored as one in analysis table, or have feature_set_prediciton link table?
	#Or only have single analysis feature which can contribute to multi analysis "regulons"
	#Or can we have multiple entries in feature_set with the same id but different analyses?
	#This would still not be specific for each feature, nor would the regulatory_feature analysis_id
	#reflect all the combined analyses.  Maybe just the one which contributed most?
	
	
	my $seq_region_id;
	($rf, $seq_region_id) = $self->_pre_store($rf);
	$rf->adaptor($self);#Set adaptor first to allow attr feature retreival for bounds
	#This is only required when storing, 
	
	$sth->bind_param(1, $seq_region_id,             SQL_INTEGER);
	$sth->bind_param(2, $rf->start(),               SQL_INTEGER);
	$sth->bind_param(3, $rf->end(),                 SQL_INTEGER);
	$sth->bind_param(4, $rf->bound_start(),         SQL_INTEGER);
	$sth->bind_param(5, $rf->bound_end(),           SQL_INTEGER);
	$sth->bind_param(6, $rf->strand(),              SQL_TINYINT);
	$sth->bind_param(7, $rf->{'display_label'},     SQL_VARCHAR);#Direct access so we always store the binary string
	$sth->bind_param(8, $rf->feature_type->dbID(),  SQL_INTEGER);
	$sth->bind_param(9, $rf->feature_set->dbID(),   SQL_INTEGER);
	$sth->bind_param(10, $rf->{'stable_id'},        SQL_INTEGER);
	
	$sth->execute();
	$rf->dbID( $sth->{'mysql_insertid'} );

	my $table_type;
	my %attrs = %{$rf->_attribute_cache()};

	foreach my $table(keys %attrs){
	  ($table_type = $table)  =~ s/_feature//;

	  foreach my $id(keys %{$attrs{$table}}){
		$sth2->bind_param(1, $rf->dbID,   SQL_INTEGER);
		$sth2->bind_param(2, $id,         SQL_INTEGER);
		$sth2->bind_param(3, $table_type, SQL_VARCHAR);
		$sth2->execute();
	  }
	}
  }
  
  return \@rfs;
}


=head2 fetch_all_by_Slice

  Arg [1]    : Bio::EnsEMBL::Slice
  Example    : my $slice = $sa->fetch_by_region('chromosome', '1');
               my $features = $regf_adaptor->fetch_all_by_Slice($slice);
  Description: Retrieves a list of features on a given slice, specific for the current 
               default RegulatoryFeature set.
  Returntype : Listref of Bio::EnsEMBL::RegulatoryFeature objects
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub fetch_all_by_Slice {
  my ($self, $slice) = @_;
	
  my $fset = $self->_get_current_FeatureSet;

  return (defined $fset) ? $self->fetch_all_by_Slice_FeatureSets($slice, [$self->_get_current_FeatureSet]) : undef;
}



1;
