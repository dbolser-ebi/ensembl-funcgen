-- Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

/**
@header patch_90_91_zh.sql - Add new columns to read_file_experimental_configuration table
@desc   Add new columns to read_file_experimental_configuration table
*/

alter table read_file_experimental_configuration add column paired_end_tag int DEFAULT null;
alter table read_file_experimental_configuration add column multiple       int DEFAULT 1;

-- patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_90_91_zh.sql|Add new columns to read_file_experimental_configuration table');