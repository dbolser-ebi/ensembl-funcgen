package Bio::EnsEMBL::Funcgen::HiveConfig::Ftp::ExportPeakCallingDescriptions;

use strict;
use warnings;
use base 'Bio::EnsEMBL::Funcgen::HiveConfig::Ftp::Base';
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Hash::Util qw( lock_hash );

sub beekeeper_extra_cmdline_options {
    my ($self) = @_;
    return '-reg_conf ' . $self->o('reg_conf') . ' -meadow_type LOCAL';
}

sub pipeline_analyses {
    my $self = shift;
    
    my $data_freeze_date = $self->o('data_freeze_date');
    
    my $ftp_layout_configuration = {
      peak_calling_description_file_dir  => '#ftp_base_dir#/#species#/Peaks/#epigenome_production_name#/#feature_type_name#',
      peak_calling_description_file_name => "#species#.#assembly#.#epigenome_production_name#.#feature_type_name#.#analysis_logic_name#.peaks_description.${data_freeze_date}.txt",
    };

    lock_hash(%$ftp_layout_configuration);

    return [
        {   -logic_name  => 'start_export',
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into   => {
              MAIN => 'create_peak_calling_description_jobs',
            }
        },
        {   -logic_name  => 'create_peak_calling_description_jobs',
            -module      => 'Bio::EnsEMBL::Funcgen::Hive::Ftp::CreatePeakCallingDescriptionJobs',
            -flow_into   => {
               2 => 'create_peak_calling_description',
            },
        },
        {   -logic_name  => 'create_peak_calling_description',
            -module      => 'Bio::EnsEMBL::Funcgen::Hive::Ftp::CreatePeakCallingDescription',
            -parameters  => {
                file_name => 
                  $ftp_layout_configuration->{peak_calling_description_file_dir}
                  . '/' . $ftp_layout_configuration->{peak_calling_description_file_name}
                ,
            },
        },
    ]
}

1;