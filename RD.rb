###
#
# This ruby script compares Reptile Database (by downloading
# http://reptile-database.reptarium.cz/interfaces/export/taxa.csv)
# with extant Reptile species on iNaturalist
#
###
require 'open-uri'
require 'csv'
require 'json'

#These are species in Reptile Database that are known to be extinct and are thus ignored...
known_extinct = ["Aldabrachelys abrupta","Aldabrachelys grandidieri","Chelonoidis abingdonii","Chelonoidis niger","Alinea luciae", "Bolyeria multocarinata", "Borikenophis sanctaecrucis", "Celestus occiduus", "Chioninia coctei", "Clelia errabunda", "Copeoglossum redondae", "Emoia nativitatis", "Erythrolamprus perfuscus", "Hoplodactylus delcourti", "Leiocephalus cuneus", "Leiocephalus eremitus", "Leiocephalus herminieri", "Leiolopisma mauritiana", "Oligosoma northlandi", "Phelsuma gigas", "Pholidoscelis cineraceus", "Pholidoscelis major", "Scelotes guentheri", "Tachygyia microlepis", "Tetradactylus eastwoodae", "Typhlops cariei"]
puts "Downdloading data from Reptile Database..."
rd_data = []
url = "http://reptile-database.reptarium.cz/interfaces/export/taxa.csv"
CSV.new(open(url), :headers => :first_row, :col_sep => ";").each do |row|
  name = row['taxon_id'].split("_").join(" ")
  unless known_extinct.include? name
    rank = row['infraspecific_epithet'].nil? ? "species" : "subspecies"
    parent = (rank == "species") ? name.split(" ")[0] : name.split(" ")[0..1].join(" ")
    rd_data << {name: name, parent: parent, rank: rank, genus: row['genus'], family: row['family']}
  end
end

# Use the iNat API to find all species descending from the Reptile root
puts "Using the iNat API to find all species descending from the Reptile root..."
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

# Hardcode the inat_taxon id for class Reptilia
root_taxon_id = 26036
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

#These are intentional discrepancies between Reptile Database and whats on iNat
discrepancies = [
  #inat would merge 
  {rd: ["Crotalus atrox"], inat: ["Crotalus tortugensis", "Crotalus atrox"]}, #https://www.inaturalist.org/taxa/map?taxa=30764,121085
  {rd: ["Anatololacerta anatolica"], inat: ["Anatololacerta anatolica", "Anatololacerta oertzeni"]}, #https://www.inaturalist.org/taxa/map?taxa=73603,73601
  {rd: ["Acontias orientalis"], inat: ["Acontias lineicauda","Acontias orientalis"]}, #https://www.inaturalist.org/taxa/map?taxa=604083,37303
  {rd: ["Pliocercus elapoides"], inat: ["Pliocercus bicolor","Pliocercus elapoides"]}, #https://www.inaturalist.org/taxa/map?taxa=121082,73912
  {rd: ["Trapelus ruderatus"], inat: ["Trapelus lessonae","Trapelus ruderatus"]}, #https://www.inaturalist.org/taxa/map?taxa=73979,31354
  {rd: ["Macrochelys temminckii"], inat: ["Macrochelys apalachicolae","Macrochelys temminckii"]}, #https://www.inaturalist.org/taxa/map?taxa=521316,521318
  {rd: ["Lampropeltis zonata"], inat: ["Lampropeltis multifasciata","Lampropeltis zonata"]}, #https://www.inaturalist.org/taxa/map?taxa=371963,371962
  {rd: ["Aspidoscelis inornatus"], inat: ["Aspidoscelis arizonae","Aspidoscelis inornata"]}, #https://www.inaturalist.org/taxa/map?taxa=73651,73673
  {rd: ["Aspidoscelis tigris"], inat: ["Aspidoscelis catalinensis","Aspidoscelis canus","Aspidoscelis tigris"]}, #https://www.inaturalist.org/taxa/map?taxa=121101,38671,121100
  {rd: ["Ctenotus inornatus"], inat: ["Ctenotus helenae","Ctenotus inornatus","Ctenotus saxatilis","Ctenotus fallens"]}, #https://www.inaturalist.org/taxa/map?taxa=37058,37091,37096,37106
  #inat would split
  {rd: ["Emys marmorata","Emys pallida"], inat: ["Actinemys marmorata"]}, #https://www.inaturalist.org/taxa/map?taxa=521330,521331
  {rd: ["Salvadora deserticola","Salvadora hexalepis"], inat: ["Salvadora hexalepis"]}, #https://www.inaturalist.org/taxa/map?taxa=558943,606618
  {rd: ["Cyclura stejnegeri", "Cyclura cornuta"], inat: ["Cyclura cornuta"]}, #https://www.inaturalist.org/taxa/map?taxa=146565,35295
  {rd: ["Terrapene carolina","Terrapene mexicana","Terrapene yucatana"], inat: ["Terrapene carolina"]}, #https://www.inaturalist.org/taxa/map?taxa=606754,521325,521323
  {rd: ["Sceloporus occidentalis","Sceloporus becki"], inat: ["Sceloporus occidentalis"]}, #https://www.inaturalist.org/taxa/map?taxa=540190,606756
  {rd: ["Kinosternon steindachneri","Kinosternon subrubrum"], inat: ["Kinosternon subrubrum"]}, #https://www.inaturalist.org/taxa/map?taxa=521326,521329
  {rd: ["Drymarchon couperi","Drymarchon kolpobasileus"], inat: ["Drymarchon couperi"]}, #https://www.inaturalist.org/taxa/map?taxa=539630,606723
  {rd: ["Phrynosoma hernandesi","Phrynosoma bauri","Phrynosoma brevirostris","Phrynosoma diminutum","Phrynosoma ornatissimum","Phrynosoma douglasii"], inat: ["Phrynosoma hernandesi","Phrynosoma douglasii"]}, #https://www.inaturalist.org/taxa/map?taxa=606761,606763,540095,540094,540093,540092
  #inat would swap:
  {rd: ["Kinosternon stejnegeri"], inat: ["Kinosternon arizonense"]},
  {rd: ["Holbrookia approximans"], inat: ["Holbrookia maculata"]},
  {rd: ["Emys blandingii"], inat: ["Emydoidea blandingii"]},
  {rd: ["Uma cowlesi"], inat: ["Uma rufopunctata"]},
  {rd: ["Indotyphlops braminus"], inat: ["Ramphotyphlops braminus"]},
  #inat would add:
  {rd: ["Trachemys medemi"], inat: []}, #newly described turtle species not yet in Turtles of the world
  #skip these reptile database species (they are duplicates that they should remove - that happen to be involved in the changes above too)
  {rd: ["Aspidoscelis inornata"], inat: []},
  {rd: ["Actinemys marmorata"], inat: []},
  {rd: ["Kinosternon arizonense"], inat: []},
  {rd: ["Holbrookia maculata"], inat: []},
  {rd: ["Emydoidea blandingii"], inat: []},
  {rd: ["Uma rufopunctata"], inat: []},
  #skip these reptile database species (they are duplicates that they should remove)
  {rd: ["Crocodylus raninus"], inat: []},
  {rd: ["Homopus boulengeri"], inat: []},
  {rd: ["Alinea berengerae"], inat: []},
  {rd: ["Alinea pergravis"], inat: []},
  {rd: ["Pholidoscelis corvina"], inat: []},
  {rd: ["Lophognathus burnsi"], inat: []},
  {rd: ["Naja crawshayi"], inat: []},
  {rd: ["Trachylepis ivensii"], inat: []},
  {rd: ["Liasis papuana"], inat: []},
  {rd: ["Chioninia geisthardti"], inat: []},
  {rd: ["Diploglossus legnotus"], inat: []},
  {rd: ["Diploglossus ingridae"], inat: []},
  {rd: ["Cercosaura argula"], inat: []},
  {rd: ["Lamprolepis vyneri"], inat: []},
  {rd: ["Draco timorensis"], inat: []},
  {rd: ["Orthriophis cantoris"], inat: []},
  {rd: ["Orthriophis hodgsoni"], inat: []},
  {rd: ["Orthriophis moellendorffi"], inat: []},
  {rd: ["Orthriophis taeniurus"], inat: []},
  {rd: ["Flaviemys purvisi"], inat: []},
  {rd: ["Calliophis bivirgata"], inat: []},
  {rd: ["Anguis incomptus"], inat: []},
  {rd: ["Ctenosaura defensor"], inat: []},
  {rd: ["Scincella rara"], inat: []},
  {rd: ["Pholidoscelis chrysolaema"], inat: []},
  {rd: ["Pholidoscelis erythrocephala"], inat: []},
  {rd: ["Pholidoscelis fuscata"], inat: []},
  {rd: ["Uropeltis rubromaculatus"], inat: []},
  {rd: ["Uropeltis ceylanicus"], inat: []},
  {rd: ["Trachylepis septemtaeniata"], inat: []},
  {rd: ["Trachylepis aurata"], inat: []},
  {rd: ["Thamnophis valida"], inat: []},
  {rd: ["Uropeltis melanogaster"], inat: []},
  {rd: ["Altiphylax yarkandensis"], inat: []},
  {rd: ["Siagonodon unguirostris"], inat: []},
  {rd: ["Plectrurus canaricus"], inat: []},
  {rd: ["Pholidoscelis taeniura"], inat: []},
  {rd: ["Pholidoscelis pluvianotata"], inat: []},
  {rd: ["Pholidoscelis lineolata"], inat: []},
  {rd: ["Pholidoscelis cineracea"], inat: []},
  {rd: ["Phelsuma nigra"], inat: []},
  {rd: ["Niveoscincus coventryi"], inat: []},
  {rd: ["Niveoscincus greeni"], inat: []},
  {rd: ["Niveoscincus metallicus"], inat: []},
  {rd: ["Niveoscincus microlepidotus"], inat: []},
  {rd: ["Niveoscincus ocellatus"], inat: []},
  {rd: ["Niveoscincus orocryptus"], inat: []},
  {rd: ["Niveoscincus palfreymani"], inat: []},
  {rd: ["Niveoscincus pretiosus"], inat: []},
  {rd: ["Cercosaura argula"], inat: []},
  {rd: ["Vermicella calonotus"], inat: []},
  {rd: ["Homopus signatus"], inat: []},
  {rd: ["Homopus solus"], inat: []},
  {rd: ["Thamnophis saurita"], inat: []},
  {rd: ["Aspidoscelis costatus"], inat: []}, 
  {rd: ["Aspidoscelis flagellicaudus"], inat: []}, 
  {rd: ["Aspidoscelis guttatus"], inat: []}, 
  {rd: ["Aspidoscelis xanthonotus"], inat: []}, 
  {rd: ["Aspidoscelis tesselatus"], inat: []}, 
  {rd: ["Aspidoscelis hyperythrus"], inat: []}, 
  {rd: ["Aspidoscelis inornatus"], inat: []}, 
  {rd: ["Aspidoscelis lineattissimus"], inat: []}, 
  {rd: ["Aspidoscelis marmoratus"], inat: []}, 
  {rd: ["Aspidoscelis maximus"], inat: []}, 
  {rd: ["Aspidoscelis mexicanus"], inat: []}, 
  {rd: ["Aspidoscelis neomexicanus"], inat: []}, 
  {rd: ["Aspidoscelis neotesselatus"], inat: []}, 
  {rd: ["Aspidoscelis parvisocius"], inat: []}, 
  {rd: ["Aspidoscelis pictus"], inat: []}, 
  {rd: ["Aspidoscelis sexlineatus"], inat: []}, 
  {rd: ["Aspidoscelis stictogrammus"], inat: []}, 
  {rd: ["Cnemidophorus martyris"], inat: []}, 
  {rd: ["Chelonoidis phantastica"], inat: []},
  #keep these NZ 'species' in iNaturalist until further investigation
  {rd: [], inat: ["Naultinus \"north cape\""]},
  {rd: [], inat: ["Hoplodactylus \"southern alps\""]},
  {rd: [], inat: ["Hoplodactylus \"marlborough\""]},
  {rd: [], inat: ["Hoplodactylus \"southern north island\""]},
  {rd: [], inat: ["Hoplodactylus \"central otago\""]},
  {rd: [], inat: ["Hoplodactylus \"mokohinaus\""]},
  {rd: [], inat: ["Hoplodactylus \"cromwell\""]},
  {rd: [], inat: ["Hoplodactylus \"poor knights\""]},
  {rd: [], inat: ["Hoplodactylus \"matapia\""]},
  {rd: [], inat: ["Hoplodactylus \"three kings\""]},
  {rd: [], inat: ["Hoplodactylus \"mt arthur\""]},
  {rd: [], inat: ["Hoplodactylus \"kaikouras\""]},
  {rd: [], inat: ["Hoplodactylus \"otago large\""]},
  {rd: [], inat: ["Hoplodactylus \"southern mini\""]},
  {rd: [], inat: ["Hoplodactylus \"okarito\""]},
  {rd: [], inat: ["Hoplodactylus \"cascade\""]},
  {rd: [], inat: ["Hoplodactylus \"open bay islands"]},
  {rd: [], inat: ["Hoplodactylus \"roys peak\""]},
  {rd: [], inat: ["Hoplodactylus \"southern forest\""]},
  {rd: [], inat: ["Hoplodactylus \"north cape\""]},
  {rd: [], inat: ["Hoplodactylus \"open bay islands\""]},
  {rd: [], inat: ["Oligosoma \"whirinaki\""]} #https://www.inaturalist.org/observations/1541119  
]

leftovers = discrepancies.map{|row| row[:rd]}.flatten - rd_data.select{ |a| a[:rank] == "species" }.map{ |a| a[:name] }
if leftovers.count > 0
  puts "These are no longer in the RD"
  leftovers.each do |name|
    puts "\t" + name
  end
end

added = (discrepancies.map{|row| row[:inat]}.flatten.uniq - discrepancies.map{|row| row[:rd]}.flatten.uniq) &  rd_data.select{ |a| a[:rank] == "species" }.map{ |a| a[:name] }
if added.count > 0
  puts "These have been added to the RD"
  added.each do |name|
    puts "\t" + name
  end
end

# These are species in iNat, not in RD
not_in_rd = ( inat_names.map{ |row| row[:name] } - rd_data.select{ |a| a[:rank] == "species" }.map{ |a| a[:name] } )
if not_in_rd.count > 0
  puts "These are species in iNat, not in RD..."
  not_in_rd.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:inat]}.flatten.include? name
      puts "\t" + name
    end
  end
end
#build swaps from these to indicate how these taxa should be dealt with
swaps = Hash.new

# These are species in RD, not in iNat
not_in_inat = ( rd_data.select{ |a| a[:rank] == "species" }.map{ |a| a[:name] } - inat_names.map{ |row| row[:name] } )
if not_in_inat.count > 0
  puts "These are species in RD, not in iNat..."
  not_in_inat.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:rd]}.flatten.include? name
      #ignore taxa accounted for by the above swaps
      unless swaps.values.include? name
        puts "\t" + name
      end
    end
  end
end
