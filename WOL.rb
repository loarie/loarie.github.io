###
#
# This ruby script loops compares a WOL CSV downloaded from
# https://www.pugetsound.edu/files/resources/world-odonata-214.xls
# with Odonata extant species on iNaturalist
#
###

require 'uri'
require 'csv'
require 'net/http'
require 'json'

# Load up a hash of names from a CSV export from WOL
puts "Load up a hash of names from a CSV export from WOL..."
wol_names = []
species = nil
genus = nil
family = nil
CSV.foreach( "world_odonata_214.csv", :headers => true, :col_sep => ",", :encoding => 'iso-8859-1:utf-8' ) do |row|
   if !row[1].nil?
     if row[2].split.count > 1
       genus = row[2].split[0]
     else
       family = row[2].downcase.capitalize
     end
   end
   if row[0] == "0"
     species = row[2].split[0..1].join( " " )
     wol_names << { species: species, genus: genus, family: family }
   end
end

# Use the iNat API to find all species descending from the Odonata root
puts "Using the iNat API to find all species descending from the Odonata root..."
def one_node( ids )
  # Just do 100 at a time to avoid long URLs
  per_page = 100
  iters = ( ids.count / per_page.to_f ).ceil
  ( 0..( iters - 1 ) ).each do |i|
    sub_ids = ids[( per_page * i )..( per_page * i + 99 )]
    url = "https://api.inaturalist.org/v1/taxa/#{ sub_ids.join( "," ) }?per_page=#{ per_page }"
    uri = URI( url )
    response = Net::HTTP.get( uri ); nil
    dat = JSON.parse( response ); nil
    # Sleep a bit to keep under 1.6req/sec and avoid hammering the iNat API
    sleep 0.625
    parents = dat["results"]
    parents.each do |parent|
      if parent["rank_level"] > 10 && parent["children"]
        new_ids = parent["children"].map{ |row| row["id"] }
        if parent["rank_level"] == 20
          # If the parent is rank genus, stop and store the taxon_ids
          SPECIES << new_ids
        else
          # Otherwise dig deeper
          one_node( new_ids )
        end
      end
    end
  end
end

# Hardcode the inat_taxon id for order Odonata
root_taxon_id = 47792
SPECIES = []
# Iterate down from the root taxon collecting species
one_node( [root_taxon_id] )
raw_inat_taxon_ids = SPECIES.flatten; nil

# Use the iNat API to exclude extinct species and hybrids
puts "Using the iNat API to exclude extinct species and hybrids..."
inat_names = []
per_page = 100
iters = ( raw_inat_taxon_ids.count / per_page.to_f ).ceil
( 0..( iters - 1 ) ).each do |i|
  sub_sp = raw_inat_taxon_ids[( per_page * i )..( per_page*i+99 )]
  url = "https://api.inaturalist.org/v1/taxa/#{ sub_sp.join( "," ) }?per_page=#{ per_page }"
  uri = URI( url )
  response = Net::HTTP.get( uri ); nil
  dat = JSON.parse( response ); nil
  # Sleep a bit to keep under 1.6req/sec and avoid hammering the iNat API
  sleep 0.625
  parents = dat["results"]
  parents.each do |parent|
    unless parent["rank"] == "hybrid" || parent["extinct"] == true
      inat_names << { name: parent["name"], taxon_id: parent["id"] } 
    end
  end
end

# These are species in WOL, not in iNat
not_in_inat = ( wol_names.map{ |a| a[:species] } - inat_names.map{ |row| row[:name] } )
if not_in_inat.count > 0
  puts "These are species in WOL, not in iNat..."
  not_in_inat.map{ |name| puts "\t" + name }
end

# These are species in WOL, not in iNat
not_in_wol = ( inat_names.map{ |row| row[:name] } - wol_names.map{ |a| a[:species] } )
if not_in_wol.count > 0
  puts "These are species in iNat, not in WOL..."
  not_in_wol.map{ |name| puts "\t" + name }
end

