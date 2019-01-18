###
#
# This ruby script compares IUCN Mammals (by downloading from
#http://www.iucnredlist.org/)
# with extant Mammal species on iNaturalist
#
###

require 'uri'
require 'net/http'
require 'open-uri'
require 'csv'
require 'json'

#These are mammal species in IUCN that are known to be extinct and are thus ignored...
puts "Downdloading data from IUCN..."
bigdat = []
(0..9).each do |i|
  url = "http://apiv3.iucnredlist.org/api/v3/species/page/#{i}?token=9bb4facb6d23f48efbf424bb05c0c1ef1cf6f468393bc745d42179ac4aca5fee"
  uri = URI(url)
  response = Net::HTTP.get(uri); nil
  dat = JSON.parse(response); nil
  bigdat << dat["result"]
end
bigdat = bigdat.flatten; nil
iucn = bigdat.select{|a| (a["class_name"] == "MAMMALIA") && a["category"] != "EX" && a["population"].nil? && a["infra_rank"].nil? && a["infra_name"].nil?}; nil

# Use the iNat API to find all species descending from the Mammal root
puts "Using the iNat API to find all species descending from the Mammal root..."
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

=begin
# Hardcode the inat_taxon id for class Reptilia
root_taxon_id = 40151
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
=end

taxon_framework = TaxonFramework.find(19)

ancestry_string = taxon_framework.taxon.rank == "stateofmatter" ?
  "#{ taxon_framework.taxon_id }" : "#{ taxon_framework.taxon.ancestry }/#{ taxon_framework.taxon.id }"

internal_taxa = Taxon.select( "taxa.id, taxa.name, taxa.rank, taxa.rank_level, parent.id AS parent_id, parent.name AS parent_name, parent.rank AS parent_rank").
  where( "taxa.ancestry = ? OR taxa.ancestry LIKE ?", ancestry_string, "#{ancestry_string}/%" ).
  where( is_active: true ).
  joins( "JOIN taxa parent ON parent.id = (string_to_array(taxa.ancestry, '/')::int[])[array_upper(string_to_array(taxa.ancestry, '/')::int[],1)]" ).
  where( "taxa.rank_level >= ? ", taxon_framework.rank_level).
  where("( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0")

#These are intentional discrepancies between IUCN and whats on iNat
iucn_discrepancies = [
   #domestic species in iNat, not in IUCN, leaving them
    {iucn: [], inat: ["Equus caballus"]},
    {iucn: [], inat: ["Equus asinus"]},
    {iucn: [], inat: ["Canis familiaris"]},
    {iucn: [], inat: ["Felis catus"]},
    {iucn: [], inat: ["Bos taurus"]},
    {iucn: [], inat: ["Ovis aries"]},
    {iucn: [], inat: ["Capra hircus"]},
    {iucn: [], inat: ["Bubalus bubalis"]},
    {iucn: [], inat: ["Bos indicus"]},
    {iucn: [], inat: ["Lama glama"]},
    {iucn: [], inat: ["Vicugna pacos"]},
    {iucn: [], inat: ["Camelus dromedarius"]},
    {iucn: [], inat: ["Camelus bactrianus"]},
    {iucn: [], inat: ["Cavia porcellus"]},

    #newly described species added to iNat not yet in IUCN, leaving them
    {iucn: [], inat: ["Monodelphis pinocchio"]},
    {iucn: [], inat: ["Monodelphis saci"]},
    {iucn: [], inat: ["Euroscaptor orlovi"]},
    {iucn: [], inat: ["Euroscaptor kuznetsovi"]},
    {iucn: [], inat: ["Gracilimus radix"]},
    {iucn: [], inat: ["Neusticomys vossi"]},
    {iucn: [], inat: ["Tupaia discolor"]}, #(make range) https://www.researchgate.net/publication/241277673_Using_hand_proportions_to_test_taxonomic_boundaries_within_the_Tupaia_glis_species_complex_Scandentia_Tupaiidae
  
    #iNat would merge
    {iucn: ["Thylamys cinderella"], inat: ["Thylamys sponsorius", "Thylamys cinderella"]},
    {iucn: ["Sminthopsis fuliginosus"], inat: ["Sminthopsis fuliginosus", "Sminthopsis aitkeni"]},
    {iucn: ["Sorex antinorii"], inat: ["Sorex arunchi", "Sorex antinorii"]},
    {iucn: ["Crocidura poensis"], inat: ["Crocidura fingui", "Crocidura poensis"]},
    {iucn: ["Ictidomys mexicanus"], inat: ["Ictidomys mexicanus", "Ictidomys parvidens"]},
    {iucn: ["Sciurus vulgaris"], inat: ["Sciurus meridionalis","Sciurus vulgaris"]},
    {iucn: ["Glaucomys sabrinus"], inat: ["Glaucomys sabrinus","Glaucomys oregonensis"]},
    {iucn: ["Otospermophilus beecheyi"], inat: ["Otospermophilus beecheyi","Otospermophilus atricapillus"]},
    {iucn: ["Thomomys umbrinus"], inat: ["Thomomys umbrinus", "Thomomys sheldoni", "Thomomys atrovarius", "Thomomys nayarensis"]},#https://oup.silverchair-cdn.com/oup/backfile/Content_public/Journal/jmammal/94/5/10.1644/13-MAMM-A-013.1/2/m_jmammal-94-5-983-fig1.png?Expires=1547631214&Signature=av3gY~Z~ppMTRmYVeBOymiERcGj5Oc8fVHoBSQtfJmeYmek35dUbsWCBGlhHU4Bw7njLNPqgd5WrCZId3ITcVxRUAJB2CkHnCqViBaRkICkk5gT-BbBrgajegJm7Oq52wz7SKBM1kqDarbya4INAkrvTGhNrZSeXWmSYEiTk-1hbrhjZp54QFXbtqjpUdcGwG0YQPia~6VzEjQC6ayY0Um5LfGNulXjvqwxCpUIV2XJSUzIYHutDLr-fkm~SGJkzgCCfztRlw2uVFcFqAf8~3OVgrUNvzWWqk7ZEUDBrPb-QhsEiExtowue2dsdDuOTq1QLfxlhyW9jsf0dp3OeMzw__&Key-Pair-Id=APKAIE5G5CRDK6RD3PGA
    {iucn: ["Loxodonta africana"], inat: ["Loxodonta cyclotis","Loxodonta africana"]},
    {iucn: ["Dipodomys phillipsii"], inat: ["Dipodomys phillipsii", "Dipodomys ornatus"]}, #https://academic.oup.com/view-large/figure/15985248/jmammal-93-2-560-fig1.tiff

    #inat would split
    {iucn: ["Urocitellus brunneus","Urocitellus endemicus"], inat: ["Urocitellus brunneus"]},
    {iucn: ["Hylobates muelleri","Hylobates abbotti","Hylobates funereus"], inat: ["Hylobates muelleri"]},
    {iucn: ["Marmosops caucae", "Marmosops impavidus"], inat: ["Marmosops impavidus"]},
    {iucn: ["Cebus brunneus", "Cebus castaneus"], inat: ["Cebus olivaceus"]}, #IUCN wants to split C. olivaceus into C. castaneus, C. brunneus & C. olivaceus but currently have just pulled C. olivaceus (sensu lato) and just added C. brunneus with no range  
    {iucn: ["Pithecia pissinattii","Pithecia vanzolinii"], inat: ["Pithecia irrorata"]}, #IUCN wants to split P. irrorata into P. vanzolinii,rylandsi,mittermeieri, & pissinattii, but currently have just pulled P. irrorata (sensu lato) and just added P. vanzolinii and P. pissinattii
    {iucn: ["Cebus albifrons","Cebus cuscinus","Cebus aequatorialis","Cebus cesarae","Cebus malitiosus","Cebus versicolor"], inat: ["Cebus albifrons"]}, #IUCN wants to split C. albifrons into C. albifrons,cuscinus,aequatorialis,cesarae,malitiosus, & versicolor, but currently have just added the additional taxa with no ranges and not reassessed C. albifrons

     #inat would swap
    {iucn: ["Ochotona pallasii"], inat: ["Ochotona pallasi"]},
    {iucn: ["Gerbillus mackilligini"], inat: ["Gerbillus mackillingini"]},

    #mysteriously removed from IUCN for seemingly no good reason, leaving them
    {iucn: [], inat: ["Alouatta seniculus"]},
    {iucn: [], inat: ["Mico manicorensis"]},
    {iucn: [], inat: ["Cebus capucinus"]}, #presumably pulled to split off C. imator
    {iucn: [],  inat: ["Cercopithecus pogonias"]},

    #ditch
    {iucn: ["Pseudoberylmys muongbangensis"], inat: []}, #determined to just be Berylmys bowersi

    #bats (thanks bobby23!)
    #swaps
    {iucn: ["Proechimys trinitatis"], inat: ["Proechimys trinitatus"]},
    {iucn: ["Hipposideros cyclops"], inat: ["Doryrhina cyclops"]},
    {iucn: ["Baeodon alleni"], inat: ["Rhogeessa alleni"]},
    {iucn: ["Nycticeinops schlieffeni"], inat: ["Nycticeinops schlieffenii"]},
    {iucn: ["Hipposideros gigas"], inat: ["Macronycteris gigas"]},
    {iucn: ["Hipposideros thomensis"], inat: ["Macronycteris thomensis"]},
    {iucn: ["Hipposideros vittatus"], inat: ["Macronycteris vittatus"]},
    {iucn: ["Baeodon gracilis"], inat: ["Rhogeessa gracilis"]},
    {iucn: ["Lonchophylla pattoni"], inat: ["Hsunycteris pattoni"]},
    {iucn: ["Lonchophylla cadenai"], inat: ["Hsunycteris cadenai"]},
    {iucn: ["Lonchophylla thomasi"], inat: ["Hsunycteris thomasi"]},  
    {iucn: ["Hipposideros commersoni"], inat: ["Macronycteris commersonii"]}, #Hipposideros commersonii (iNat) should be swapped with Macronycteris commersoni (ASM); IUCN recognizes Hipposideros commersoni* 
    {iucn: ["Nycticeinops schlieffeni"], inat: ["Nycticeinops schlieffenii"]}, #2 i's
    {iucn: ["Pipistrellus hesperus"], inat: ["Parastrellus hesperus"]}, #Parastrellus hesperus (iNat/ASM) in place of Pipistrellus Hesperus (IUCN) 
    {iucn: ["Scotonycteris ophiodon"], inat: ["Casinycteris ophiodon"]}, #Casinycteris ophiodon (iNat/ASM) in place of Scotonycteris ophiodon (IUCN)
    {iucn: ["Lissonycteris angolensis"], inat: ["Myonycteris angolensis"]}, #Myonycteris angolensis (iNat/ASM) in place of Lissonycteris angolensis (IUCN) 
    #split
    {iucn: ["Molossus bondae", "Molossus currentium"], inat: ["Molossus currentium"]},#Molossus bondae (IUCN, 2017) is treated as Molossus currentium (ASM) 
    {iucn: ["Triaenops rufus", "Triaenops persicus"], inat: ["Triaenops persicus"]}, #Triaenops rufus (IUCN, 2017) is treated as Triaenops persicus (ASM); it traditionally applies to the Madagascan population of T. persicus; some authorities treat them synonymous, others keep them distinct
    #merge
    {iucn: ["Plecotus kolombatovici"], inat: ["Plecotus kolombatovici", "Plecotus gaisleri"]},
    {iucn: ["Rhinolophus pusillus"], inat: ["Rhinolophus monoceros", "Rhinolophus pusillus"]},
    #new
    {iucn: [], inat: ["Dermanura rava"]},
    {iucn: [], inat: ["Dryadonycteris capixaba"]},  
    {iucn: [], inat: ["Scotophilus alvenslebeni"]}, #Scotophilus alvenslebeni (iNat/ASM) should be retained
    {iucn: [], inat: ["Nyctophilus corbeni"]}, #Nyctophilus corbeni (iNat/ASM) should be retained 
    {iucn: [], inat: ["Nyctophilus major"]}, #Nyctophilus major (iNat/ASM) should be retained
    {iucn: [], inat: ["Glauconycteris atra"]}, #Glauconycteris atra (iNat) should be retained; it is a recently described species (Hassanin et al. 2018) 
    {iucn: [], inat: ["Hypsugo lanzai"]}, #Pipistrellus lanzai (iNat) should be swapped with Hypsugo lanzai (ASM) 
    {iucn: [], inat: ["Neoromicia stanleyi"]}, #Pipistrellus stanleyi (iNat) should be swapped with Neoromicia stanleyi (ASM) 
    {iucn: [], inat: ["Miniopterus fuliginosus"]}, #Miniopterus fuliginosus (iNat/ASM) should be retained 
    {iucn: [], inat: ["Miniopterus oceanensis"]}, #Miniopterus oceanensis (iNat/ASM) should be retained 
    {iucn: [], inat: ["Miniopterus mossambicus"]}, #Miniopterus mossambicus (iNat/ASM) should be retained 
    {iucn: [], inat: ["Miniopterus villiersi"]}, #Miniopterus villiersi (iNat) is not on the IUCN Red List or ASM Database. The Catalogue of Life (CoL) recognizes "Miniopterus schreibersii villiersi", a name recognized by Wikipedia's bat contributors as well. However, neither IUCN or ASM recognize subspecies for Miniopterus schreibersii. Primary literature from the last decade recognize Miniopterus villiersi as a species in-text. Based on the general direction of the literature, I tentatively suggest we leave it alone for now. Jakob may know more, since it's an African bat. 
    {iucn: [], inat: ["Sturnira thomasi"]}, #Sturnira thomasi (iNat) lacks recent literature and is in neither database; the IUCN use to have an assessment for it published in 1996, but it was pulled from their database over a decade ago
    {iucn: [], inat: ["Dermanura incomitatus"]}, #Artibeus incomitatus (iNat) should be swapped with Dermanura incomitatus (ASM) 
    {iucn: [], inat: ["Macronycteris cryptovalorona"]}, #Hipposideros cryptovalorona (iNat) should be swapped with Macronycteris cryptovalorona (ASM) 
    {iucn: [], inat: ["Pteropus pelewensis"]}, #Pteropus pelewensis (iNat/ASM) should be retained 
    {iucn: [], inat: ["Pteropus pelagicus"]}, #Pteropus insularis (iNat) should be swapped with Pteropus pelagicus (ASM) 
    {iucn: [], inat: ["Dobsonia magna"]}, #Dobsonia magna (iNat) is not formally on the IUCN Red List, but is mentioned in the taxonomic note for Dobsonia moluccensis: "Dobsonia moluccensis has been considered separate from Dobsonia magna (Bergmans and Sarbini 1985), but more taxonomic work needs to be conducted to clarify their taxonomy (Helgen 2007)". There statement implies D. magna and D. moluccensis should tentatively be recognized as separate taxa, and I recommend we follow that position on iNat. D. magna is missing from the ASM Database, but is included on CoL. 
    {iucn: [], inat: ["Scotonycteris occidentalis"]}, #Scotonycteris occidentalis (iNat/ASM) should be retained 
    {iucn: [], inat: ["Scotonycteris bergmansi"]}, #Scotonycteris bergmansi (iNat/ASM) should be retained 
    {iucn: [], inat: ["Rhinolophus geoffroyi"]}, #Rhinolophus geoffroyi (iNat) should be retained; it traditionally is treated as a synonym of R. clivosus, but Stoffberg et al. (2012) finds mitochondrial differentiation; it's not listed as a synonym of R. clivosus on IUCN
    {iucn: [], inat: ["Rhinolophus willardi"]}, #Rhinolophus willardi (iNat/ASM) should be retained 
    {iucn: [], inat: ["Rhinolophus mabuensis"]}, #Rhinolophus mabuensis (iNat/ASM) should be retained 
    {iucn: [], inat: ["Rhinolophus horaceki"]}, # (iNat/ASM) should be retained 
    {iucn: [], inat: ["Rhinolophus nippon"]}, #Rhinolophus nippon (iNat) should be retained; it has no assessment page, but IUCN authors state that “although Thomas (1997, unpublished thesis) found very high divergence in mitochondrial DNA sequences, Csorba et al. 2003 refrained from splitting Japanese greater horseshoe bats (Rhinolophus nippon) from R. ferrumequinum”; this suggests that they would support it 
    {iucn: [], inat: ["Rhinolophus kahuzi"]}, #Rhinolophus kahuzi (iNat/ASM) should be retained 
    {iucn: [], inat: ["Triaenops menamena"]}, #Triaenops menamena (iNat/ASM) should be retained.
    {iucn: [], inat: ["Hipposideros nicobarulae"]} #Hipposideros nicobarulae (iNat/ASM) should be retained; IUCN recognizes Hipposideros ater* 
  ]


ind = iucn_discrepancies.select{|a| (a[:iucn].count == 1) & (a[:inat].count == 1)}
swap_key = ind.map{|a| [a[:inat][0],a[:iucn][0]]}.to_h
swaps = ind.map{|a| a[:inat][0]}.to_set

other = iucn_discrepancies.select{|a| (a[:iucn].count != 1) || (a[:inat].count != 1)}.map{|a| a[:inat]}.flatten.uniq.to_set
other_ids = internal_taxa.select{|a| other.include? a.name}.map{|a| a.id}
swaps_ids = internal_taxa.select{|a| swaps.include? a.name}.map{|a| a.id}
Taxon.find(other_ids).map{|a| a.taxon_ranges.where('source_id IS NULL OR source_id != 7830').count}
Taxon.find(swaps_ids).map{|a| a.taxon_ranges.where('source_id IS NULL OR source_id != 7830').count}

rest_ids = internal_taxa.select{|a| (a.rank == 'species') & (!other.include? a.name) & (!swaps.include? a.name)}.map{|a| a.id}
Taxon.find(rest_ids).select{|a| a.taxon_ranges.where("source_id IS NULL OR source_id != 7830").count != 1}.map{|a| puts a.id}

Taxon.find(internal_taxa.select{|a| a.rank=="species"}.map{|a| a.id}).select{|a| a.taxon_ranges.where("source_id IS NULL OR source_id != 7830").count != 1}.map{|a| puts a.id}

mults = []
internal_taxa.select{|a| a[:rank]=="species"}.each do |taxon|
  name = taxon.name
  if other.include? name
    puts name
    next
  end
  name = swap_key[name] if swap_key[name]
  iucn_id = iucn.select{|a| a["scientific_name"]==name}.first["taxonid"]
  #puts iucn_id
  
  shapefile_path = "/home/inaturalist/iucn_shps/test#{iucn_id}_geo_raw_dis.shp"
  begin
    shape = GeoRuby::Shp4r::ShpFile.open(shapefile_path).first
  rescue
    puts "#{name} rescue"
    next #no range
  end
  geom = shape.geometry; nil
  
  if geom.is_a?( GeoRuby::SimpleFeatures::Geometry )
    georuby_geom = geom
    geom = RGeo::WKRep::WKBParser.new.parse( georuby_geom.as_wkb )
  end
  if geom.blank? #doens't have range so add it
    puts "#{name} missing"
    next #no range
  end
  if taxon.taxon_ranges.where('source_id IS NULL OR source_id != 7830').count > 1
    mults << taxon.id
    next
  end
  unless tr = taxon.taxon_ranges.where('source_id IS NULL OR source_id != 7830').first
    tr = TaxonRange.new(taxon_id: taxon.id)
  end
  tr.geom = geom
  tr.save!
  puts taxon.id
end

#issue 1, geom is a GeoRuby::SimpleFeatures::Geometry but RGeo::WKRep::WKBParser.new.parse( georuby_geom.as_wkb ) returns nil
#issue 2   
ogr2ogr iucn_shps/test22732_geo_raw_dis.shp iucn_shps_raw/test22732_geo_raw.shp -simplify 0.01 -dialect sqlite -sql 'SELECT ST_Union(ST_MakeValid(geometry)) FROM test22732_geo_raw'
GEOS error: TopologyException: Input geom 1 is invalid: Ring Self-intersection at or near point 75.344566115341962 34.289863691101502 at 75.344566115341962 34.289863691101502

Panthera uncia rescue
Canis familiaris
Failed to find polygon for inner ring!
Failed to find polygon for inner ring!
Canis aureus rescue
Failed to find polygon for inner ring!
Failed to find polygon for inner ring!
Failed to find polygon for inner ring!
Failed to find polygon for inner ring!
Otaria byronia missing


psql inaturalist_production -c "COPY ( 
SELECT ST_AsKML(ST_SetSRID(geom, 4326)) FROM taxon_ranges WHERE taxon_id = 850031
) TO STDOUT WITH CSV HEADER" > pika.kml



Piliocolobus pennantii #we have a range that looks good
Pithecia milleri #manually made range
Homo sapiens #no range

Ochotona pallasi - manual range


leftovers = iucn_discrepancies.map{|row| row[:iucn]}.flatten - iucn.map{|row| row["scientific_name"]}
if leftovers.count > 0
  puts "These are no longer in the IUCN"
  leftovers.each do |name|
    puts "\t" + name
  end
end

added = (iucn_discrepancies.map{|row| row[:inat]}.flatten.uniq - iucn_discrepancies.map{|row| row[:iucn]}.flatten.uniq) &  iucn.map{|row| row["scientific_name"]}
if added.count > 0
  puts "These have been added to the IUCN"
  added.each do |name|
    puts "\t" + name
  end
end

# These are species in iNat, not in IUCN
res = []
not_in_iucn = ( internal_taxa.select{|i| i.rank == "species"}.map{ |row| row.name } - iucn.map{|row| row["scientific_name"]} )
if not_in_iucn.count > 0
  puts "These are species in iNat, not in IUCN..."
  not_in_iucn.each do |name|
    #ignore discrepancies
    unless iucn_discrepancies.map{|row| row[:inat]}.flatten.include? name
      puts "\t" + name
      res << name
    end
  end
end

#build swaps from these to indicate how these taxa should be dealt with
swaps = Hash.new
# These are species in IUCN, not in iNat
res = []
not_in_inat = ( iucn.map{|row| row["scientific_name"]} - internal_taxa.select{|i| i.rank == "species"}.map{ |row| row.name })
if not_in_inat.count > 0
  puts "These are species in RD, not in iNat..."
  not_in_inat.each do |name|
    #ignore discrepancies
    unless iucn_discrepancies.map{|row| row[:iucn]}.flatten.include? name
      #ignore taxa accounted for by the above swaps
      unless swaps.values.include? name
        puts "\t" + name + "\t" + iucn.select{|a| a["scientific_name"] == name }[0]["order_name"].downcase.capitalize
        res << name #if iucn.select{|a| a["scientific_name"] == name }[0]["order_name"].downcase.capitalize == "Chiroptera"
      end
    end
  end
end


#manually drew ranges for
Pithecia milleri 


#These are intentional discrepancies between IUCN and whats on iNat
old_discrepancies = [
#domestic species in iNat, not in IUCN, leaving them
{iucn: [], inat: ["Equus caballus"]},
{iucn: [], inat: ["Equus asinus"]},
{iucn: [], inat: ["Canis familiaris"]},
{iucn: [], inat: ["Felis catus"]},
{iucn: [], inat: ["Bos taurus"]},
{iucn: [], inat: ["Ovis aries"]},
{iucn: [], inat: ["Capra hircus"]},
{iucn: [], inat: ["Bubalus bubalis"]},
{iucn: [], inat: ["Bos indicus"]},
{iucn: [], inat: ["Lama glama"]},
{iucn: [], inat: ["Vicugna pacos"]},
{iucn: [], inat: ["Camelus dromedarius"]},
{iucn: [], inat: ["Camelus bactrianus"]},
{iucn: [], inat: ["Cavia porcellus"]},
#newly described species added to iNat not yet in IUCN, leaving them
{iucn: [], inat: ["Monodelphis pinocchio"]},
{iucn: [], inat: ["Monodelphis saci"]},
{iucn: [], inat: ["Euroscaptor orlovi"]},
{iucn: [], inat: ["Euroscaptor kuznetsovi"]},
{iucn: [], inat: ["Gracilimus radix"]},
{iucn: [], inat: ["Neusticomys vossi"]},
#iNat would merge
{iucn: ["Sciurus vulgaris"], inat: ["Sciurus meridionalis","Sciurus vulgaris"]},
{iucn: ["Glaucomys sabrinus"], inat: ["Glaucomys sabrinus","Glaucomys oregonensis"]},
{iucn: ["Ictidomys mexicanus"], inat: ["Ictidomys mexicanus", "Ictidomys parvidens"]},
{iucn: ["Otospermophilus beecheyi"], inat: ["Otospermophilus beecheyi","Otospermophilus atricapillus"]},
{iucn: ["Thomomys umbrinus"], inat: ["Thomomys umbrinus", "Thomomys sheldoni", "Thomomys atrovarius"]},
{iucn: ["Proechimys trinitatis"], inat: ["Proechimys urichi","Proechimys trinitatus"]},
{iucn: ["Proechimys guairae"], inat: ["Proechimys poliopus", "Proechimys guairae"]},
{iucn: ["Clyomys laticeps"], inat: ["Clyomys bishopi", "Clyomys laticeps"]},
{iucn: ["Trinomys setosus"], inat: ["Trinomys myosuros", "Trinomys setosus"]},
{iucn: ["Lagidium viscacia"], inat: ["Lagidium peruanum", "Lagidium viscacia"]},
{iucn: ["Dasyprocta leporina"], inat: ["Dasyprocta cristata", "Dasyprocta leporina"]},
{iucn: ["Coendou quichua"], inat: ["Coendou rothschildi","Coendou quichua"]},
{iucn: ["Heterogeomys lanius"], inat: ["Orthogeomys lanius"]},
{iucn: ["Heterogeomys dariensis"], inat: ["Orthogeomys dariensis","Orthogeomys thaeleri"]},
{iucn: ["Heterogeomys cherriei"], inat: ["Orthogeomys matagalpae","Orthogeomys cherriei"]},
{iucn: ["Chaetodipus ammophilus"], inat: ["Chaetodipus dalquesti","Chaetodipus ammophilus"]},
{iucn: ["Dipodomys merriami"], inat: ["Dipodomys merriami", "Dipodomys insularis", "Dipodomys margaritae"]},
{iucn: ["Monodelphis glirina"], inat: ["Monodelphis maraxina","Monodelphis glirina"]},
{iucn: ["Monodelphis scalops"], inat: ["Monodelphis theresa","Monodelphis scalops"]},
{iucn: ["Monodelphis americana"], inat: ["Monodelphis rubida","Monodelphis americana","Monodelphis umbristriatus"]},
{iucn: ["Thylamys cinderella"], inat: ["Thylamys sponsorius","Thylamys cinderella"]},
{iucn: ["Chaetophractus vellerosus"], inat: ["Chaetophractus nationi","Chaetophractus vellerosus"]},
{iucn: ["Loxodonta africana"], inat: ["Loxodonta cyclotis","Loxodonta africana"]},
{iucn: ["Alces alces"], inat: ["Alces americanus","Alces alces"]},
{iucn: ["Sminthopsis fuliginosus"], inat: ["Sminthopsis fuliginosus","Sminthopsis aitkeni"]},
{iucn: ["Crocidura poensis"], inat: ["Crocidura fingui","Crocidura poensis"]},
{iucn: ["Sorex antinorii"], inat: ["Sorex arunchi","Sorex antinorii"]},
{iucn: ["Ochotona roylei"], inat: ["Ochotona roylei", "Ochotona himalayana"]},
{iucn: ["Ochotona dauurica"], inat: ["Ochotona dauurica", "Ochotona huangensis"]},
{iucn: ["Ochotona gloveri"], inat: ["Ochotona muliensis", "Ochotona gloveri"]},
{iucn: ["Ochotona forresti"], inat: ["Ochotona forresti", "Ochotona nigritia", "Ochotona gaoligongensis"]},
#inat would split
{iucn: ["Urocitellus brunneus","Urocitellus endemicus"], inat: ["Urocitellus brunneus"]},
{iucn: ["Hylobates muelleri","Hylobates abbotti","Hylobates funereus"], inat: ["Hylobates muelleri"]},
{iucn: ["Lutreolina massoia","Lutreolina crassicaudata"], inat: ["Lutreolina crassicaudata"]},
{iucn: ["Marmosops caucae", "Marmosops impavidus"], inat: ["Marmosops impavidus"]},
{iucn: ["Monodelphis peruviana", "Monodelphis adusta"], inat: ["Monodelphis adusta"]},
{iucn: ["Ochotona pallasii", "Ochotona opaca"], inat: ["Ochotona pallasi"]},
{iucn: ["Ochotona hyperborea", "Ochotona coreana", "Ochotona mantchurica"], inat: ["Ochotona hyperborea"]},
{iucn: ["Pithecia chrysocephala","Pithecia pithecia"], inat: ["Pithecia pithecia"]}, #IUCN wants to split P. pithecia into P. pithecia and P. chrysocephala, but currently have just added P. chrysocephala with no range
{iucn: ["Cebus albifrons","Cebus cuscinus","Cebus aequatorialis","Cebus cesarae","Cebus malitiosus","Cebus versicolor"], inat: ["Cebus albifrons"]}, #IUCN wants to split C. albifrons into C. albifrons,cuscinus,aequatorialis,cesarae,malitiosus, & versicolor, but currently have just added the additional taxa with no ranges and not reassessed C. albifrons
#inat would swap
{iucn: ["Cebus brunneus"], inat: ["Cebus olivaceus"]}, #IUCN wants to split C. olivaceus into C. brunneus & C. olivaceus but currently have just pulled C. olivaceus (sensu lato) and just added C. brunneus with no range
{iucn: ["Pithecia milleri"], inat: ["Pithecia monachus"]}, #IUCN wants to split P. monachus into P. monachus,milleri,hirsuta,inusta,napensis,isabela, & cazuzai, but currently have just pulled P. monachus (sensu lato) and just added P. milleri with no range
{iucn: ["Pithecia vanzolinii"], inat: ["Pithecia irrorata"]}, #IUCN wants to split P. irrorata into P. vanzolinii,rylandsi,mittermeieri, & pissinattii, but currently have just pulled P. irrorata (sensu lato) and just added P. vanzolinii with no range
{iucn: ["Neotamias minimus"], inat: ["Tamias minimus"]},
{iucn: ["Neotamias merriami"], inat: ["Tamias merriami"]},
{iucn: ["Neotamias amoenus"], inat: ["Tamias amoenus"]},
{iucn: ["Neotamias townsendii"], inat: ["Tamias townsendii"]},
{iucn: ["Neotamias umbrinus"], inat: ["Tamias umbrinus"]},
{iucn: ["Neotamias dorsalis"], inat: ["Tamias dorsalis"]},
{iucn: ["Neotamias speciosus"], inat: ["Tamias speciosus"]},
{iucn: ["Neotamias sonomae"], inat: ["Tamias sonomae"]},
{iucn: ["Eutamias sibiricus"], inat: ["Tamias sibiricus"]},
{iucn: ["Neotamias quadrimaculatus"], inat: ["Tamias quadrimaculatus"]},
{iucn: ["Neotamias quadrivittatus"], inat: ["Tamias quadrivittatus"]},
{iucn: ["Neotamias panamintinus"], inat: ["Tamias panamintinus"]},
{iucn: ["Neotamias durangae"], inat: ["Tamias durangae"]},
{iucn: ["Neotamias siskiyou"], inat: ["Tamias siskiyou"]},
{iucn: ["Neotamias canipes"], inat: ["Tamias canipes"]},
{iucn: ["Neotamias bulleri"], inat: ["Tamias bulleri"]},
{iucn: ["Neotamias obscurus"], inat: ["Tamias obscurus"]},
{iucn: ["Neotamias rufus"], inat: ["Tamias rufus"]},
{iucn: ["Neotamias senex"], inat: ["Tamias senex"]},
{iucn: ["Neotamias ruficaudus"], inat: ["Tamias ruficaudus"]},
{iucn: ["Neotamias cinereicollis"], inat: ["Tamias cinereicollis"]},
{iucn: ["Neotamias alpinus"], inat: ["Tamias alpinus"]},
{iucn: ["Neotamias palmeri"], inat: ["Tamias palmeri"]},
{iucn: ["Neotamias ochrogenys"], inat: ["Tamias ochrogenys"]},
{iucn: ["Gyldenstolpia fronto"], inat: ["Kunsia fronto"]},
{iucn: ["Tanyuromys aphrastus"], inat: ["Sigmodontomys aphrastus"]},
{iucn: ["Otomys karoensis"], inat: ["Otomys saundersiae"]},
{iucn: ["Gerbillus mackilligini"], inat: ["Gerbillus mackillingini"]},
{iucn: ["Micaelamys namaquensis"], inat: ["Aethomys namaquensis"]},
{iucn: ["Micaelamys granti"], inat: ["Aethomys granti"]},
{iucn: ["Nannospalax ehrenbergi"], inat: ["Spalax ehrenbergi"]}, 
{iucn: ["Nannospalax leucodon"], inat: ["Spalax leucodon"]},
{iucn: ["Nannospalax xanthodon"], inat: ["Spalax nehringi"]},
{iucn: ["Toromys rhipidurus"], inat: ["Makalata rhipidura"]},
{iucn: ["Brassomys albidens"], inat: ["Coccymys albidens"]},
#mysteriously removed from IUCN for seemingly no good reason, leaving them
{iucn: [], inat: ["Alouatta seniculus"]},
{iucn: [], inat: ["Mico manicorensis"]},
{iucn: [], inat: ["Cacajao melanocephalus"]},
{iucn: [], inat: ["Cebus capucinus"]},
{iucn: [],  inat: ["Cercopithecus pogonias"]},
{iucn: [], inat: ["Dipodomys ornatus"]},
#bats (thanks bobby23!)
{iucn: ["Hipposideros commersoni"], inat: ["Macronycteris commersoni"]}, #Hipposideros commersonii (iNat) should be swapped with Macronycteris commersoni (ASM); IUCN recognizes Hipposideros commersoni* 
{iucn: ["Pipistrellus hesperus"], inat: ["Parastrellus hesperus"]}, #Parastrellus hesperus (iNat/ASM) in place of Pipistrellus Hesperus (IUCN) 
{iucn: ["Pipistrellus subflavus"], inat: ["Perimyotis subflavus"]},#Perimyotis subflavus (iNat/ASM) should be retained; IUCN recognizes Pipistrellus subflavus* 
{iucn: ["Scotonycteris ophiodon"], inat: ["Casinycteris ophiodon"]}, #Casinycteris ophiodon (iNat/ASM) in place of Scotonycteris ophiodon (IUCN)
{iucn: ["Triaenops rufus","Triaenops persicus"], inat: ["Triaenops persicus"]}, #Triaenops rufus (IUCN, 2017) is treated as Triaenops persicus (ASM); it traditionally applies to the Madagascan population of T. persicus; some authorities treat them synonymous, others keep them distinct
{iucn: ["Lissonycteris angolensis"], inat: ["Myonycteris angolensis"]}, #Myonycteris angolensis (iNat/ASM) in place of Lissonycteris angolensis (IUCN) 
{iucn: ["Molossus bondae","Molossus currentium"], inat: ["Molossus currentium"]},#Molossus bondae (IUCN, 2017) is treated as Molossus currentium (ASM) 
{iucn: [], inat: ["Plecotus gaisleri"]}, #Plecotus gaisleri (iNat/ASM) should be retained 
{iucn: [], inat: ["Scotophilus alvenslebeni"]}, #Scotophilus alvenslebeni (iNat/ASM) should be retained
{iucn: [], inat: ["Nycticeinops schlieffenii"]}, #Nycticeinops schlieffenii (iNat) should be retained; it is a recently described species (Koubínová et al. 2013) 
{iucn: [], inat: ["Nyctophilus corbeni"]}, #Nyctophilus corbeni (iNat/ASM) should be retained 
{iucn: [], inat: ["Nyctophilus major"]}, #Nyctophilus major (iNat/ASM) should be retained
{iucn: [], inat: ["Glauconycteris atra"]}, #Glauconycteris atra (iNat) should be retained; it is a recently described species (Hassanin et al. 2018) 
{iucn: [], inat: ["Hypsugo lanzai"]}, #Pipistrellus lanzai (iNat) should be swapped with Hypsugo lanzai (ASM) 
{iucn: [], inat: ["Neoromicia stanleyi"]}, #Pipistrellus stanleyi (iNat) should be swapped with Neoromicia stanleyi (ASM) 
{iucn: [], inat: ["Miniopterus fuliginosus"]}, #Miniopterus fuliginosus (iNat/ASM) should be retained 
{iucn: [], inat: ["Miniopterus oceanensis"]}, #Miniopterus oceanensis (iNat/ASM) should be retained 
{iucn: [], inat: ["Miniopterus mossambicus"]}, #Miniopterus mossambicus (iNat/ASM) should be retained 
{iucn: [], inat: ["Miniopterus villiersi"]}, #Miniopterus villiersi (iNat) is not on the IUCN Red List or ASM Database. The Catalogue of Life (CoL) recognizes "Miniopterus schreibersii villiersi", a name recognized by Wikipedia's bat contributors as well. However, neither IUCN or ASM recognize subspecies for Miniopterus schreibersii. Primary literature from the last decade recognize Miniopterus villiersi as a species in-text. Based on the general direction of the literature, I tentatively suggest we leave it alone for now. Jakob may know more, since it's an African bat. 
{iucn: [], inat: ["Sturnira thomasi"]}, #Sturnira thomasi (iNat) lacks recent literature and is in neither database; the IUCN use to have an assessment for it published in 1996, but it was pulled from their database over a decade ago
{iucn: [], inat: ["Dermanura incomitatus"]}, #Artibeus incomitatus (iNat) should be swapped with Dermanura incomitatus (ASM) 
{iucn: [], inat: ["Macronycteris cryptovalorona"]}, #Hipposideros cryptovalorona (iNat) should be swapped with Macronycteris cryptovalorona (ASM) 
{iucn: [], inat: ["Pteropus pelewensis"]}, #Pteropus pelewensis (iNat/ASM) should be retained 
{iucn: [], inat: ["Pteropus pelagicus"]}, #Pteropus insularis (iNat) should be swapped with Pteropus pelagicus (ASM) 
{iucn: [], inat: ["Dobsonia magna"]}, #Dobsonia magna (iNat) is not formally on the IUCN Red List, but is mentioned in the taxonomic note for Dobsonia moluccensis: "Dobsonia moluccensis has been considered separate from Dobsonia magna (Bergmans and Sarbini 1985), but more taxonomic work needs to be conducted to clarify their taxonomy (Helgen 2007)". There statement implies D. magna and D. moluccensis should tentatively be recognized as separate taxa, and I recommend we follow that position on iNat. D. magna is missing from the ASM Database, but is included on CoL. 
{iucn: [], inat: ["Scotonycteris occidentalis"]}, #Scotonycteris occidentalis (iNat/ASM) should be retained 
{iucn: [], inat: ["Scotonycteris bergmansi"]}, #Scotonycteris bergmansi (iNat/ASM) should be retained 
{iucn: [], inat: ["Rhinolophus geoffroyi"]}, #Rhinolophus geoffroyi (iNat) should be retained; it traditionally is treated as a synonym of R. clivosus, but Stoffberg et al. (2012) finds mitochondrial differentiation; it's not listed as a synonym of R. clivosus on IUCN
{iucn: [], inat: ["Rhinolophus willardi"]}, #Rhinolophus willardi (iNat/ASM) should be retained 
{iucn: [], inat: ["Rhinolophus mabuensis"]}, #Rhinolophus mabuensis (iNat/ASM) should be retained 
{iucn: [], inat: ["Rhinolophus horaceki"]}, # (iNat/ASM) should be retained 
{iucn: [], inat: ["Rhinolophus nippon"]}, #Rhinolophus nippon (iNat) should be retained; it has no assessment page, but IUCN authors state that “although Thomas (1997, unpublished thesis) found very high divergence in mitochondrial DNA sequences, Csorba et al. 2003 refrained from splitting Japanese greater horseshoe bats (Rhinolophus nippon) from R. ferrumequinum”; this suggests that they would support it 
{iucn: [], inat: ["Rhinolophus kahuzi"]}, #Rhinolophus kahuzi (iNat/ASM) should be retained 
{iucn: [], inat: ["Triaenops menamena"]}, #Triaenops menamena (iNat/ASM) should be retained.
{iucn: [], inat: ["Hipposideros nicobarulae"]} #Hipposideros nicobarulae (iNat/ASM) should be retained; IUCN recognizes Hipposideros ater* 
]

