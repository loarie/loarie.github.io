###
#
# This ruby script compares Fishbase (using the
# https://fishbase.ropensci.org/ API
# with extant species from the 6 Fish Classes on iNaturalist
#
###

require 'uri'
require 'net/http'
require 'open-uri'
require 'csv'
require 'json'

puts "fetching species from Fishbase"
url = "https://fishbase.ropensci.org/taxa?limit=1"
uri = URI( url )
response = Net::HTTP.get( uri ); nil
dat = JSON.parse( response ); nil
limit = 5000
num = dat["count"]
ceiling = (num/limit.to_f).ceil - 1

fishbase = []
known_extinct = ["Chasmistes muriei", "Moxostoma lacerum", "Ctenochromis pectoralis", "Nosferatu pantostictus", "Paraneetroplus fenestratus", "Ptychochromis onilahy", "Tristramella sacra", "Cottus echinatus", "Alburnus akili", "Alburnus nicaeensis", "Anabarilius macrolepis", "Barbodes semifasciolatus", "Chondrostoma scodrense", "Cyprinus yilongensis", "Ericymba buccata", "Evarra bustamantei", "Evarra eigenmanni", "Evarra tlahuacensis", "Gila crassicauda", "Leucos aula", "Notropis amecae", "Notropis aulidion", "Notropis saladonis", "Pogonichthys ciscoides", "Pseudophoxinus handlirschi", "Romanogobio antipai", "Aphanius splendens", "Cyprinodon ceciliae", "Cyprinodon inmemoriam", "Cyprinodon latifasciatus", "Fundulus albolineatus", "Gasterosteus crenobiontus", "Characodon garmani", "Noturus trautmani", "Centrolabrus melanocercus", "Etheostoma sellare", "Gambusia amistadensis", "Gambusia georgei", "Pantanodon madagascariensis", "Prototroctes oxyrhynchus", "Coregonus alpenae", "Coregonus bezola", "Coregonus fera", "Coregonus gutturosus", "Coregonus hiemalis", "Coregonus restrictus", "Salmo pallaryi", "Salvelinus agassizii", "Salvelinus neocomensis", "Salvelinus profundus", "Platytropius siamensis", "Hippocampus curvicuspis", "Hippocampus grandiceps", "Hippocampus hendriki", "Hippocampus lichtensteinii", "Hippocampus montebelloensis", "Hippocampus multispinus", "Hippocampus queenslandicus", "Hippocampus semispinosus", "Hippocampus suezensis", "Synodus myops", "Rhizosomichthys totae", "Labeobarbus microbarbis", "Lepidomeda altivelis", "Mirogrex hulensis", "Notropis orca", "Rhinichthys deaconi", "Stypodon signifer", "Telestes ukliva", "Cyprinodon arcuatus", "Empetrichthys merriami", "Priapella bonita", "Coregonus johannae", "Coregonus nigripinnis", "Coregonus oxyrinchus"] 
(0..ceiling).each do |i|
  url = "https://fishbase.ropensci.org/taxa?limit=#{limit}&offset=#{i*limit}"
  uri = URI( url )
  response = Net::HTTP.get( uri ); nil
  dat = JSON.parse( response ); nil
  dat["data"].each do |row|
    name =  row["Genus"] + " " + row["Species"]
    next if known_extinct.include? name
    next if name.split.count > 2 #trinomial
    fishbase << {id: row["SpecCode"], name: name, family: row["Family"], order: row["Order"], class: row["Class"]}
  end
end

puts "fetching synonyms from Fishbase"

url = "https://fishbase.ropensci.org/synonyms?limit=1"
uri = URI( url )
response = Net::HTTP.get( uri ); nil
dat = JSON.parse( response ); nil
limit = 5000
num = dat["count"]
ceiling = (num/limit.to_f).ceil - 1

fishbase_synonyms = []
(0..ceiling).each do |i|
  url = "https://fishbase.ropensci.org/synonyms?limit=#{limit}&offset=#{i*limit}"
  uri = URI( url )
  response = Net::HTTP.get( uri ); nil
  dat = JSON.parse( response ); nil
  dat["data"].each do |row|
    name =  row["SynGenus"] + " " + row["SynSpecies"]
    fishbase_synonyms << {id: row["SpecCode"], name: name}
  end
end

def synkey(input, fishbase_synonyms, fishbase)
  #input = "Chromis guentheri"
  unless syns = fishbase_synonyms.select{|row| row[:name] == input}[0]
    return nil
  end
  syn_id = syns[:id]
  unless n = fishbase.select{|row| row[:id] == syn_id}[0]
    return nil
  end
  output = n[:name]
end

fishkey = {}
fishclasses = fishbase.map{|row| row[:class]}.uniq
url = "https://api.inaturalist.org/v1/taxa/355675"
uri = URI( url )
response = Net::HTTP.get( uri ); nil
dat = JSON.parse( response ); nil
dat["results"][0]["children"].each do |child|
  if fishclasses.include? child["name"]
    fishkey[child["name"]] = child["id"]
  end
end

# Use the iNat API to find all species descending from the 6 Fish Class roots
puts "Using the iNat API to find all species descending from the 6 Fish Class roots..."
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
    sleep 0.75
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

inat_names = []
fishkey.keys.each do |fishclass|
  puts "working on #{fishclass}"
  # Hardcode the inat_taxon id for class Reptilia
  root_taxon_id = fishkey[fishclass]
  SPECIES = []
  # Iterate down from the root taxon collecting species
  one_node( [root_taxon_id] )
  raw_inat_taxon_ids = SPECIES.flatten; nil
  
  # Use the iNat API to exclude extinct species and hybrids
  puts "Using the iNat API to exclude extinct species and hybrids..."
  per_page = 100
  iters = ( raw_inat_taxon_ids.count / per_page.to_f ).ceil
  ( 0..( iters - 1 ) ).each do |i|
    sub_sp = raw_inat_taxon_ids[( per_page * i )..( per_page*i+99 )]
    url = "https://api.inaturalist.org/v1/taxa/#{ sub_sp.join( "," ) }?per_page=#{ per_page }"
    uri = URI( url )
    response = Net::HTTP.get( uri ); nil
    dat = JSON.parse( response ); nil
    # Sleep a bit to keep under 1.6req/sec and avoid hammering the iNat API
    sleep 0.75
    parents = dat["results"]
    parents.each do |parent|
      unless parent["rank"] == "hybrid" || parent["extinct"] == true
        inat_names << { name: parent["name"], taxon_id: parent["id"] } 
      end
    end
  end
end

discrepancies = [
  #the Fishbase API isn't exactly the same as Fishbase
  #these aren't in the Fishbase API, but are in the Fishbase website so leaving them
  {fishbase: [], inat: ["Macrhybopsis etnieri"]},
  {fishbase: [], inat: ["Macrhybopsis tomellerii"]},
  {fishbase: [], inat: ["Macrhybopsis pallida"]},
  {fishbase: [], inat: ["Macrhybopsis boschungi"]},
  {fishbase: [], inat: ["Rhizosomichthys totae"]},
  {fishbase: [], inat: ["Nosferatu pantostictus"]},
  {fishbase: [], inat: ["Aethotaxis mitopteryx"]},
  {fishbase: [], inat: ["Leucos aula"]},
  {fishbase: [], inat: ["Merluccius gayi"]},
  {fishbase: [], inat: ["Nettorhamphos radula"]},
  {fishbase: [], inat: ["Neotrygon trigonoides"]},
  {fishbase: [], inat: ["Neotrygon australiae"]},
  {fishbase: [], inat: ["Micropterus haiaka"]},
  {fishbase: [], inat: ["Stegastes marginatus"]},
  {fishbase: [], inat: ["Pomacentrus maafu"]},
  {fishbase: [], inat: ["Sirembo amaculata"]},
  {fishbase: [], inat: ["Sirembo wami"]},
  {fishbase: [], inat: ["Pomacentrus magniseptus"]},
  {fishbase: [], inat: ["Pomacentrus micronesicus"]},
  {fishbase: [], inat: ["Altrichthys alelia"]},
  {fishbase: [], inat: ["Prognathodes basabei"]},
  {fishbase: [], inat: ["Centropyge cocosensis"]},
  {fishbase: [], inat: ["Monacoa niger"]},
  {fishbase: [], inat: ["Tylosurus acus"]},
  {fishbase: [], inat: ["Barbodes semifasciolatus"]},
  {fishbase: [], inat: ["Centrolabrus melanocercus"]},
  {fishbase: [], inat: ["Speolabeo musaei"]},
  {fishbase: [], inat: ["Trachinocephalus trachinus", "Trachinocephalus myops", "Trachinocephalus gauguini"]}, #Synodus myops in fishbase but not the API, we're splitting/moving Synodus
  {fishbase: ["Gasterosteus aculeatus","Gasterosteus gymnurus"], inat: ["Gasterosteus aculeatus","Gasterosteus nipponicus"]},
  {fishbase: ["Labidesthes sicculus"], inat: ["Labidesthes vanhyningi","Labidesthes sicculus"]},
  #Explicit deviations for fishbase
  {fishbase: ["Pseudoxiphophorus obliquus"], inat: ["Heterandria obliqua"]}, #Fishbase has it in Pseudoxiphophorus and departs from the API with Pseudoxiphophorus anzuetoi	(Rosen & Bailey, 1979).Pseudoxiphophorus bimaculatus,Pseudoxiphophorus cataractae,Pseudoxiphophorus diremptus,Pseudoxiphophorus jonesii,Pseudoxiphophorus litoperas
  {fishbase: ["Hippocampus alatus", "Hippocampus spinosissimus"], inat: ["Hippocampus spinosissimus"]}, # via IUCN seahorse group
  {fishbase: ["Hippocampus procerus","Hippocampus whitei"], inat: ["Hippocampus whitei"]}, # via IUCN seahorse group
  {fishbase: ["Hippocampus waleananus","Hippocampus satomiae"], inat: ["Hippocampus satomiae"]}, # via IUCN seahorse group
  {fishbase: ["Hippocampus biocellatus","Hippocampus trimaculatus"], inat: ["Hippocampus trimaculatus", "Hippocampus planifrons", "Hippocampus dahli"]}, # via IUCN seahorse group
  {fishbase: ["Hippocampus fuscus","Hippocampus borboniensis","Hippocampus kuda"], inat: ["Hippocampus kuda"]}, # via IUCN seahorse group
  {fishbase: ["Pegasus volitans"], inat: ["Pegasus tetrabelos", "Pegasus volitans"]},
  {fishbase: ["Cheilinus fasciatus"], inat: ["Cheilinus quinquecinctus","Cheilinus fasciatus"]},
  {fishbase: ["Chrysiptera brownriggii"], inat: ["Chrysiptera leucopoma","Chrysiptera brownriggii"]},
  {fishbase: ["Poecilia sphenops"], inat: ["Poecilia thermalis","Poecilia sphenops"]},
  {fishbase: ["Synodus variegatus"], inat: ["Synodus houlti", "Synodus variegatus"]},
  {fishbase: ["Antennatus coccineus"], inat: ["Antennarius nummifer","Antennatus coccineus"]},
  {fishbase: ["Lethrinus lentjan"], inat: ["Lethrinus punctulatus","Lethrinus lentjan"]},
  {fishbase: ["Pagrus auratus"], inat: ["Chrysophrys auratus"]},
  {fishbase: ["Acanthurus nigricansm"], inat: ["Acanthurus nigricans"]}, #fishbase type
  {fishbase: ["Zebrasoma veliferum"], inat: ["Zebrasoma velifer"]},      #cof uses Z. velifer
  {fishbase: ["Synchiropus rameus"], inat: ["Orbonymus rameus"]},      #cof uses Orbonymus
  {fishbase: ["Crenimugil seheli"], inat: ["Moolgarda seheli"]},          #cof uses Moolgarda
  {fishbase: ["Helotes sexlineatus"], inat: ["Pelates sexlineatus"]},     #see https://www.inaturalist.org/taxon_changes/27850
  {fishbase: ["Schistura denisoni"], inat: ["Nemacheilus denisoni"]},
  {fishbase: ["Planiliza haematocheila"], inat: ["Liza haematocheila"]},
  {fishbase: ["Dajaus monticola"], inat: ["Agonostomus monticola"]},
  {fishbase: ["Chelon ramada"], inat: ["Liza ramada"]},
  {fishbase: ["Chelon aurata"], inat: ["Liza aurata"]},
  {fishbase: ["Pelates octolineatus"], inat: ["Helotes octolineatus"]},
  # newly discovered not yet in fishbase:
  {fishbase: [], inat: ["Dellichthys trnskii"]},
  {fishbase: [], inat: ["Trachelochismus aestuarium"]},
  {fishbase: [], inat: ["Hippocampus casscsio"]}, # via IUCN seahorse group
  #need to vet and keep of find destinations for/inactivate these names not in Fishbase
  {fishbase: [], inat: ["Rhinogobius nganfoensis"]},
  {fishbase: [], inat: ["Rhinogobius vinhensis"]},
  {fishbase: [], inat: ["Cryptocentroides argulus"]},
  {fishbase: [], inat: ["Pseudogobius melanosticta"]},
  {fishbase: [], inat: ["Oxyurichthys zeta"]},
  {fishbase: [], inat: ["Hazeus diacanthus"]},
  {fishbase: [], inat: ["Egglestonichthys ulbubunitj"]},
  {fishbase: [], inat: ["Pseudocaranx georgianus"]},
  {fishbase: [], inat: ["Teleocichla preta"]},
  {fishbase: [], inat: ["Percina apina"]},
  {fishbase: [], inat: ["Pomadasys approximans"]},
  {fishbase: [], inat: ["Mullus barbatus"]},
  {fishbase: [], inat: ["Ozichthys albimaculosus"]},
  {fishbase: [], inat: ["Dentex carpenteri"]},
  {fishbase: [], inat: ["Scorpis hectori"]},
  {fishbase: [], inat: ["Scorpis boops"]},
  {fishbase: [], inat: ["Scorpis australis"]},
  {fishbase: [], inat: ["Parascolopsis rufomaculata"]},
  {fishbase: [], inat: ["Nemadactylus carponotatus"]},
  {fishbase: [], inat: ["Nemadactylus concinnus"]},
  {fishbase: [], inat: ["Cheilodactylus antonii"]},
  {fishbase: [], inat: ["Cheilodactylus aspersus"]},
  {fishbase: [], inat: ["Cheilodactylus carmichaelis"]},
  {fishbase: [], inat: ["Microdesmus longispinnis"]},
  {fishbase: [], inat: ["Gobiomorphus gobiodes"]},
  {fishbase: [], inat: ["Ditrema temminckii"]},
  {fishbase: [], inat: ["Boroda malua"]},
  {fishbase: [], inat: ["Eucinostomus californiensis"]},
  {fishbase: [], inat: ["Pseudocalliurichthys goodladi"]},
  {fishbase: [], inat: ["Bathycallionymus bifilum"]},
  {fishbase: [], inat: ["Bathycallionymus kailolae"]},
  {fishbase: [], inat: ["Calliurichthys afilum"]},
  {fishbase: [], inat: ["Calliurichthys australis"]},
  {fishbase: [], inat: ["Calliurichthys ogilbyi"]},
  {fishbase: [], inat: ["Foetorepus apricus"]},
  {fishbase: [], inat: ["Foetorepus grandoculis"]},
  {fishbase: [], inat: ["Pterosynchiropus occidentalis"]},
  {fishbase: [], inat: ["Repomucenus filamentosus"]},
  {fishbase: [], inat: ["Repomucenus keeleyi"]},
  {fishbase: [], inat: ["Repomucenus meridionalis"]},
  {fishbase: [], inat: ["Repomucenus sublaevis"]},
  {fishbase: [], inat: ["Repomucenus belcheri"]},
  {fishbase: [], inat: ["Stichaeus punctatus"]},
  {fishbase: [], inat: ["Heteropriacanthus carolinus"]},
  {fishbase: [], inat: ["Heteropriacanthus fulgens"]},
  {fishbase: [], inat: ["Olisthops brownii"]},
  {fishbase: [], inat: ["Sillago burra"]},
  {fishbase: [], inat: ["Uranoscopus terraereginae"]},
  {fishbase: [], inat: ["Hypopterus macroptera"]},
  {fishbase: [], inat: ["Aurigequula longispinis"]},
  {fishbase: [], inat: ["Psenes hillii"]},
  {fishbase: [], inat: ["Emmelichthys nitidus"]},
  {fishbase: [], inat: ["Matsubaraea fusiformis"]},
  {fishbase: [], inat: ["Puntius euspilurus"]},
  {fishbase: [], inat: ["Dionda flavipinnis"]},
  {fishbase: [], inat: ["Scaphesthes tamusuiensis"]},
  {fishbase: [], inat: ["Anabarilius liui"]},
  {fishbase: [], inat: ["Sarcocheilichthys variegatus"]},
  {fishbase: [], inat: ["Physoschistura chulabhornae"]},
  {fishbase: [], inat: ["Orthrias angorae"]},
  {fishbase: [], inat: ["Beaufortia schaueri"]},
  {fishbase: [], inat: ["Beaufortia orbifolia"]},
  {fishbase: [], inat: ["Beaufortia micrantha"]},
  {fishbase: [], inat: ["Meuschenia scabra"]},
  {fishbase: [], inat: ["Aluterus abassai"]},
  {fishbase: [], inat: ["Acanthostracion bucephalus"]},
  {fishbase: [], inat: ["Chilomycterus spinosus"]},
  {fishbase: [], inat: ["Scorpaena africana"]},
  {fishbase: [], inat: ["Scorpaena aculeata"]},
  {fishbase: [], inat: ["Sebastolobus varispinis"]},
  {fishbase: [], inat: ["Trachyscorpia cristulata"]},
  {fishbase: [], inat: ["Onigocia macrocephala"]},
  {fishbase: [], inat: ["Platycephalus angustus"]},
  {fishbase: [], inat: ["Platycephalus australis"]},
  {fishbase: [], inat: ["Liparis madrensis"]},
  {fishbase: [], inat: ["Liparis makinoana"]},
  {fishbase: [], inat: ["Notoliparis stewarti"]},
  {fishbase: [], inat: ["Paraliparis copei"]},
  {fishbase: [], inat: ["Kanekonia leichhardti"]},
  {fishbase: [], inat: ["Hoplichthys mimaseanus"]},
  {fishbase: [], inat: ["Doryrhamphus excisus"]},
  {fishbase: [], inat: ["Phyllopteryx dewysea"]},
  {fishbase: [], inat: ["Halicampus ensenadae"]},
  {fishbase: [], inat: ["Pseudoxiphophorus jonesii"]},
  {fishbase: [], inat: ["Allodontichtys hubbsi"]},
  {fishbase: [], inat: ["Allodontichtys polylepis"]},
  {fishbase: [], inat: ["Allodontichtys tamazulae"]},
  {fishbase: [], inat: ["Ariosoma hemiaspidus"]},
  {fishbase: [], inat: ["Chaetostoma anomala"]},
  {fishbase: [], inat: ["Olyra taquara"]},
  {fishbase: [], inat: ["Oreoglanis hponkanensis"]},
  {fishbase: [], inat: ["Engyprosopon osculum"]},
  {fishbase: [], inat: ["Monolene maculipina"]},
  {fishbase: [], inat: ["Etropus delsmani"]},
  {fishbase: [], inat: ["Brachirus breviceps"]},
  {fishbase: [], inat: ["Brachirus fitzroiensis"]},
  {fishbase: [], inat: ["Pardachirus rautheri"]},
  {fishbase: [], inat: ["Pseudaesopia callizona"]},
  {fishbase: [], inat: ["Symphurus sitgmosus"]},
  {fishbase: [], inat: ["Paraplagusia bleekeri"]},
  {fishbase: [], inat: ["Clupea pallasii"]},
  {fishbase: [], inat: ["Gephyrocharax atricaudatus"]},
  {fishbase: [], inat: ["Saccoderma falcata"]},
  {fishbase: [], inat: ["Pygopristis denticulatus"]},
  {fishbase: [], inat: ["Leporinus enyae"]},
  {fishbase: [], inat: ["Pterodiscus cookei"]},
  {fishbase: [], inat: ["Galaxias arcanus"]},
  {fishbase: [], inat: ["Galaxias mungadhan"]},
  {fishbase: [], inat: ["Galaxias aequipinnis"]},
  {fishbase: [], inat: ["Galaxias brevissimus"]},
  {fishbase: [], inat: ["Galaxias gunaikurnai"]},
  {fishbase: [], inat: ["Galaxias lanceolatus"]},
  {fishbase: [], inat: ["Galaxias longifundus"]},
  {fishbase: [], inat: ["Galaxias mcdowalli"]},
  {fishbase: [], inat: ["Galaxias oliros"]},
  {fishbase: [], inat: ["Galaxias supremus"]},
  {fishbase: [], inat: ["Galaxias tantangara"]},
  {fishbase: [], inat: ["Galaxias terenasus"]},
  {fishbase: [], inat: ["Mallotus philippinensis"]},
  {fishbase: [], inat: ["Argentina tapetodes"]},
  {fishbase: [], inat: ["Nansenia boreacrassicauda"]},
  {fishbase: [], inat: ["Dolicholagus longirosytis"]},
  {fishbase: [], inat: ["Platybelone argalus"]},
  {fishbase: [], inat: ["Strongylura notata"]},
  {fishbase: [], inat: ["Hyporhamphus roberti"]},
  {fishbase: [], inat: ["Cheilopogon pinnatibarbatus"]},
  {fishbase: [], inat: ["Menidia alchichica"]},
  {fishbase: [], inat: ["Menidia ferdebueni"]},
  {fishbase: [], inat: ["Menidia labarcae"]},
  {fishbase: [], inat: ["Menidia letholepis"]},
  {fishbase: [], inat: ["Menidia promelas"]},
  {fishbase: [], inat: ["Menidia squamata"]},
  {fishbase: [], inat: ["Menidia bartoni"]},
  {fishbase: [], inat: ["Menidia charari"]},
  {fishbase: [], inat: ["Menidia riojai"]},
  {fishbase: [], inat: ["Menidia aculeatum"]},
  {fishbase: [], inat: ["Atherinella pellosemion"]},
  {fishbase: [], inat: ["Atherinosoma elongatum"]},
  {fishbase: [], inat: ["Pseudomugil luminatus"]},
  {fishbase: [], inat: ["Porophryne erythrodactylus"]},
  {fishbase: [], inat: ["Kuiterichthys pietschi"]},
  {fishbase: [], inat: ["Antennarius steffifer"]},
  {fishbase: [], inat: ["Chaunacops spinosus"]}
]

#discrepancies.map{|a| puts a[:fishbase].join(", ")+" -> "+a[:inat].join(", ")}
#discrepancies.map{|a| puts a[:inat][0] + " ???"}

leftovers = discrepancies.map{|row| row[:fishbase]}.flatten - fishbase.map{|row| row[:name]}
if leftovers.count > 0
  puts "These are no longer in Fishbase"
  leftovers.each do |name|
    puts "\t" + name
  end
end

added = (discrepancies.map{|row| row[:inat]}.flatten.uniq - discrepancies.map{|row| row[:fishbase]}.flatten.uniq) &  fishbase.map{|row| row[:name]}
if added.count > 0
  puts "These have been added to the Fishbase"
  added.each do |name|
    puts "\t" + name
  end
end

swaps = []
# These are species in iNat, not in Fishbase
not_in_fishbase = ( inat_names.map{ |row| row[:name] } - fishbase.map{|row| row[:name]} )
if not_in_fishbase.count > 0
  puts "These are species in iNat, not in Fishbase..."
  not_in_fishbase.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:inat]}.flatten.include? name
      if syn = synkey(name, fishbase_synonyms, fishbase)
        swaps << {in: name, out: syn}
        puts "{in: \"" + name + "\", out: \"" + syn + "\"},"
      else
        puts "{in: \"" + name + "\", out: \"\"},"
        swaps << {in: name, out: ""}
      end
    end
  end
end

# These are 'new' species in Fishbase, not in iNat
news = []
not_in_inat = ( fishbase.map{|row| row[:name]} - inat_names.map{ |row| row[:name] } )
if not_in_inat.count > 0
  puts "These are species in Fishbase, not in iNat..."
  not_in_inat.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:fishbase]}.flatten.include? name
      puts "\t" + name
      news << fishbase.select{|row| row[:name] == name}[0]
    end
  end
end



