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
known_extinct = ["Chelonoidis phantasticus","Aldabrachelys abrupta","Aldabrachelys grandidieri","Chelonoidis abingdonii","Chelonoidis niger","Alinea luciae", "Bolyeria multocarinata", "Borikenophis sanctaecrucis", "Celestus occiduus", "Chioninia coctei", "Clelia errabunda", "Copeoglossum redondae", "Emoia nativitatis", "Erythrolamprus perfuscus", "Hoplodactylus delcourti", "Leiocephalus cuneus", "Leiocephalus eremitus", "Leiocephalus herminieri", "Leiolopisma mauritiana", "Oligosoma northlandi", "Phelsuma gigas", "Pholidoscelis cineraceus", "Pholidoscelis major", "Scelotes guentheri", "Tachygyia microlepis", "Tetradactylus eastwoodae", "Typhlops cariei"]
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
  #  turtles
  #inat would merge
   {rd: ["Trachemys venusta"], inat: ["Trachemys callirostris","Trachemys venusta"]},
   {rd: ["Macrochelys temminckii"], inat: ["Macrochelys apalachicolae","Macrochelys temminckii"]}, #https://www.inaturalist.org/taxa/map?taxa=521316,521318
   #inat would split
   {rd: ["Terrapene carolina","Terrapene mexicana","Terrapene yucatana"], inat: ["Terrapene carolina"]}, #https://www.inaturalist.org/taxa/map?taxa=606754,521325,521323
   {rd: ["Kinosternon steindachneri","Kinosternon subrubrum"], inat: ["Kinosternon subrubrum"]}, #https://www.inaturalist.org/taxa/map?taxa=521326,521329
   {rd: ["Actinemys marmorata","Actinemys pallida"], inat: ["Actinemys marmorata"]}, #https://www.inaturalist.org/taxa/map?taxa=521330,521331
   #inat would swap:
   {rd: ["Kinosternon stejnegeri"], inat: ["Kinosternon arizonense"]},
   {rd: ["Emys blandingii"], inat: ["Emydoidea blandingii"]},
   #inat would add:
   {rd: ["Trachemys medemi"], inat: []}, #newly described turtle species not yet in Turtles of the world
   {rd: ["Kinosternon vogti"], inat: []},
  #  snakes
   #inat would merge
   {rd: ["Crotalus atrox"], inat: ["Crotalus tortugensis", "Crotalus atrox"]}, #https://www.inaturalist.org/taxa/map?taxa=30764,121085
   {rd: ["Lampropeltis zonata"], inat: ["Lampropeltis multifasciata","Lampropeltis zonata"]}, #https://www.inaturalist.org/taxa/map?taxa=371963,371962
   {rd: ["Pliocercus elapoides"], inat: ["Pliocercus bicolor","Pliocercus elapoides"]}, #https://www.inaturalist.org/taxa/map?taxa=121082,73912
   #inat would split
   {rd: ["Lampropeltis greeri","Lampropeltis leonis","Lampropeltis mexicana"], inat: ["Lampropeltis mexicana"]}, #http://mesoamericanherpetology.com/uploads/3/4/7/9/34798824/hansen_and_salmon_-_lampropeltis_mexicana_paper.pdf
   {rd: ["Natrix astreptophora","Natrix helvetica","Natrix natrix"], inat: ["Natrix natrix"]}, #https://www.inaturalist.org/flags/243637#comment-1907503
   {rd: ["Drymarchon couperi","Drymarchon kolpobasileus"], inat: ["Drymarchon couperi"]}, #https://www.inaturalist.org/taxa/map?taxa=539630,606723
   {rd: ["Agkistrodon conanti", "Agkistrodon piscivorus"], inat: ["Agkistrodon piscivorus"]}, #flags 251295
   {rd: ["Agkistrodon laticinctus", "Agkistrodon contortrix"], inat: ["Agkistrodon contortrix"]}, #flags 251295
   {rd: ["Salvadora deserticola","Salvadora hexalepis"], inat: ["Salvadora hexalepis"]}, #https://www.inaturalist.org/taxa/map?taxa=558943,606618
  #  lizards
   #inat would merge
   {rd: ["Anatololacerta anatolica"], inat: ["Anatololacerta anatolica", "Anatololacerta oertzeni"]}, #https://www.inaturalist.org/taxa/map?taxa=73603,73601
   {rd: ["Acontias albigularis","Acontias wakkerstroomensis","Acontias orientalis"], inat: ["Acontias lineicauda","Acontias orientalis"]}, #https://www.inaturalist.org/flags/147679
   {rd: ["Trapelus ruderatus"], inat: ["Trapelus lessonae","Trapelus ruderatus"]}, #https://www.inaturalist.org/taxa/map?taxa=73979,31354
   {rd: ["Aspidoscelis inornatus"], inat: ["Aspidoscelis arizonae","Aspidoscelis inornata"]}, #https://www.inaturalist.org/taxa/map?taxa=73651,73673
   {rd: ["Aspidoscelis tigris"], inat: ["Aspidoscelis catalinensis","Aspidoscelis canus","Aspidoscelis tigris"]}, #https://www.inaturalist.org/taxa/map?taxa=121101,38671,121100
   {rd: ["Ctenotus inornatus"], inat: ["Ctenotus helenae","Ctenotus inornatus","Ctenotus saxatilis","Ctenotus fallens"]}, #https://www.inaturalist.org/taxa/map?taxa=37058,37091,37096,37106
   #inat would split
   {rd: ["Cyclura stejnegeri", "Cyclura cornuta"], inat: ["Cyclura cornuta"]}, #https://www.inaturalist.org/taxa/map?taxa=146565,35295
   {rd: ["Sceloporus occidentalis","Sceloporus becki"], inat: ["Sceloporus occidentalis"]}, #https://www.inaturalist.org/taxa/map?taxa=540190,606756
   {rd: ["Holbrookia approximans","Holbrookia maculata"], inat: ["Holbrookia maculata"]},
   {rd: ["Phrynosoma hernandesi","Phrynosoma bauri","Phrynosoma brevirostris","Phrynosoma diminutum","Phrynosoma ornatissimum","Phrynosoma douglasii"], inat: ["Phrynosoma hernandesi","Phrynosoma douglasii"]}, #https://www.inaturalist.org/taxa/map?taxa=606761,606763,540095,540094,540093,540092
  #inat would swap:
  {rd: ["Uma cowlesi"], inat: ["Uma rufopunctata"]},
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
  {rd: [], inat: ["Hoplodactylus \"roys peak\""]},
  {rd: [], inat: ["Hoplodactylus \"southern forest\""]},
  {rd: [], inat: ["Hoplodactylus \"north cape\""]},
  {rd: [], inat: ["Hoplodactylus \"open bay islands\""]},
  {rd: [], inat: ["Oligosoma \"whirinaki\""]} #https://www.inaturalist.org/observations/1541119  
]

leftovers = discrepancies.map{|row| row[:rd]}.flatten - rd_data.select{ |a| a[:rank] == "species" }.map{ |a| a[:name] }
if leftovers.count > 0
  puts "These are no longer in RD"
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

swaps = []

not_in_rd = ( inat_names.map{ |row| row[:name] } - rd_data.select{ |a| a[:rank] == "species" }.map{ |a| a[:name] } )
if not_in_rd.count > 0
  puts "These are species in iNat, not in RD..."
  not_in_rd.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:inat]}.flatten.include? name
      unless swaps.map{|a| a[:in]}.include? name
        puts "\t" + name
      end
    end
  end
end

# These are species in RD, not in iNat
news = []
not_in_inat = ( rd_data.select{ |a| a[:rank] == "species" }.map{ |a| a[:name] } - inat_names.map{ |row| row[:name] } )
if not_in_inat.count > 0
  puts "These are species in RD, not in iNat..."
  not_in_inat.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:rd]}.flatten.include? name
      #ignore taxa accounted for by the above swaps
      unless swaps.map{|a| a[:out]}.include? name
        puts "\t" + name
        news << name
      end
    end
  end
end

swaps = []
swaps << {in: "Anolis scapularis", out: "Anolis fuscoauratus"}
swaps << {in: "Pachydactylus goodi", out: "Pachydactylus atorquatus"}
swaps << {in: "Scincella assatus", out: "Scincella assata"}
swaps << {in: "Scincella rufocaudatus", out: "Scincella rufocaudata"}
swaps << {in: "Lygosoma mafianum", out: "Mochlus mafianum"}
swaps << {in: "Mochlus afer", out: "Mochlus sundevalli"}
swaps << {in: "Paralipinia rara", out: "Scincella rara"}
swaps << {in: "Aspidoscelis neavesi", out: "Aspidoscelis exsanguis"}
swaps << {in: "Coloptychon rhombifer", out: "Gerrhonotus rhombifer"}
swaps << {in: "Sitana bahiri -> Sitana ponticeriana"}
swaps << {in: "Liolaemus manueli", out: "Liolaemus audituvelatus"}
swaps << {in: "Atractus limitaneus", out: "Atractus collaris"}
swaps << {in: "Elachistodon westermanni", out: "Boiga westermanni"}
swaps << {in: "Kolpophis annandalei", out: "Hydrophis annandalei"}
swaps << {in: "Anilios nigricaudus", out: "Anilios guentheri"}

taxon_id = 26036
taxon_id2 = 26036
putting = []
missing = []
swaps.each do |row|
  unless input = Taxon.where("name = ? AND is_active = true AND ancestry LIKE (?)", row[:in], "%/#{taxon_id}/%").first
    puts "missing input #{row[:in]}"
    missing << row
    next
  end
  unless output = Taxon.where("name = ? AND ancestry LIKE (?)", row[:out], "%/#{taxon_id2}/%").first
    puts "missing output #{row[:out]}"
    missing << row
    next
  end
  
  tcs = TaxonChange.where(taxon_id: output.id, committed_on: nil).pluck(:id) #draf exists
  if tcs.count > 0
    if tct = TaxonChangeTaxon.where("taxon_id = ? AND taxon_change_id IN (?)", input.id, tcs).first
      putting << tct.taxon_change_id
      next
    end
  end
  tc = TaxonChange.new(
        description: "swapped in Reptile Database",
        taxon_id: output.id,
        source_id: 12,
        user_id: 477,
        type: "TaxonSwap",
        committed_on: nil,
        change_group: "11_2018 Reptile Database update 2",
        committer_id: nil
  )
  tc.save(:validate => false)
  tct = TaxonChangeTaxon.create(taxon_id: input.id, taxon_change_id: tc.id)
  puts "made taxon change for #{input.name} and #{output.name}"
end

#commit the taxon changes
loarie = User.find(477)
tcts = TaxonChangeTaxon.joins(:taxon, :taxon_change).where("taxon_changes.committed_on IS NULL AND taxon_changes.change_group = '11_2018 Reptile Database update 2'").pluck(:taxon_change_id)
tcs = TaxonChange.find(tcts)
tcs.each do |tc|
  puts tc.id
  tc.committer = loarie
  begin
    tc.commit
  rescue
    puts "oops"
  end
  #sleep(1.minute)
end

