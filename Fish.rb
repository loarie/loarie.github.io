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
    sleep 0.625
    parents = dat["results"]
    parents.each do |parent|
      unless parent["rank"] == "hybrid" || parent["extinct"] == true
        inat_names << { name: parent["name"], taxon_id: parent["id"] } 
      end
    end
  end
end

discrepancies = [
  #these arn't in the Fishbase API, but are in the Fishbase website so leaving htem
  {fishbase: [], inat: ["Neomyxine caesiovitta"]},
  {fishbase: [], inat: ["Chimaera carophila"]},
  {fishbase: [], inat: ["Hypanus dipterurus"]},
  {fishbase: [], inat: ["Neotrygon trigonoides"]},
  {fishbase: [], inat: ["Neotrygon australiae"]},
  {fishbase: [], inat: ["Potamotrygon rex"]},
  {fishbase: [], inat: ["Bathytoshia lata"]},
  {fishbase: [], inat: ["Etmopterus lailae"]}, #
  {fishbase: [], inat: ["Eptatretus cryptus"]}, #
  {fishbase: [], inat: ["Eptatretus poicilus"]},  #
  {fishbase: [], inat: ["Micropterus haiaka"]},
  {fishbase: [], inat: ["Stegastes marginatus"]},
  {fishbase: [], inat: ["Pomacentrus maafu"]},
  {fishbase: [], inat: ["Sirembo amaculata"]},
  {fishbase: [], inat: ["Sirembo wami"]},
  {fishbase: [], inat: ["Pomacentrus magniseptus"]},
  {fishbase: [], inat: ["Pomacentrus micronesicus"]},
  {fishbase: [], inat: ["Altrichthys alelia"]},
  {fishbase: [], inat: ["Prognathodes basabei"]},
  {fishbase: [], inat: ["Osteomugil engeli"]},
  #new species in iseahorse not in fishbase
  {fishbase: [], inat: ["Hippocampus casscsio"]},
  #lumped in iseahorse
  {fishbase: ["Hippocampus multispinus","Hippocampus hendriki","Hippocampus grandiceps","Hippocampus angustus"], inat: ["Hippocampus angustus"]},
  {fishbase: ["Hippocampus montebelloensis","Hippocampus zebra"], inat: ["Hippocampus zebra"]},
  {fishbase: ["Hippocampus semispinosus","Hippocampus queenslandicus","Hippocampus spinosissimus"], inat: ["Hippocampus spinosissimus"]},
  {fishbase: ["Hippocampus suezensis","Hippocampus kelloggi"], inat: ["Hippocampus kelloggi"]},
  {fishbase: ["Hippocampus lichtensteinii", "Hippocampus zosterae"], inat: ["Hippocampus zosterae"]},
  {fishbase: ["Hippocampus curvicuspis","Hippocampus histrix"], inat: ["Hippocampus histrix"]},
  #Will lump these once we have range maps
  ###{fishbase: ["Hippocampus alatus", "Hippocampus spinosissimus"], inat: ["Hippocampus spinosissimus"]},
  ###{fishbase: ["Hippocampus biocellatus","Hippocampus trimaculatus"], inat: ["Hippocampus trimaculatus", "Hippocampus planifrons", "Hippocampus dahli"]},
  ###{fishbase: ["Hippocampus procerus","Hippocampus whitei"], inat: ["Hippocampus whitei"]},
  ###{fishbase: ["Hippocampus waleananus","Hippocampus satomiae"], inat: ["Hippocampus satomiae"]},
  ###{fishbase: ["Hippocampus fuscus","Hippocampus borboniensis","Hippocampus kuda"], inat: ["Hippocampus kuda"]},
  #Explicit deviations for fishbase
  {fishbase: ["Cheilinus fasciatus"], inat: ["Cheilinus quinquecinctus","Cheilinus fasciatus"]},
  {fishbase: ["Chrysiptera brownriggii"], inat: ["Chrysiptera leucopoma","Chrysiptera brownriggii"]},
  {fishbase: ["Poecilia sphenops"], inat: ["Poecilia thermalis","Poecilia sphenops"]},
  {fishbase: ["Synodus variegatus"], inat: ["Synodus houlti", "Synodus variegatus"]},
  {fishbase: ["Antennatus coccineus"], inat: ["Antennarius nummifer","Antennatus coccineus"]},
  {fishbase: ["Synodus myops"], inat: ["Trachinocephalus myops", "Trachinocephalus trachinus"]},
  {fishbase: ["Centrolabrus melanocercus"], inat: ["Symphodus melanocercus"]},
  {fishbase: ["Nosferatu pantostictus"], inat: ["Herichthys pantostictus"]},
  {fishbase: ["Paraneetroplus bifasciatus"], inat: ["Paraneetroplus bifasciatus","Vieja bifasciata"]},
  {fishbase: ["Paraneetroplus fenestratus"], inat: ["Vieja fenestrata"]},
  {fishbase: ["Barbodes semifasciolatus"], inat: ["Puntius semifasciolatus"]},
  {fishbase: ["Leucos aula"], inat: ["Rutilus aula"]},
  {fishbase: ["Ericymba buccata"], inat: ["Notropis buccatus"]},
  {fishbase: ["Lethrinus lentjan"], inat: ["Lethrinus punctulatus","Lethrinus lentjan"]},
  {fishbase: ["Pagrus auratus"], inat: ["Pagrus auratus","Chrysophrys auratus"]},
  #need to vet and keep of find destinations for/inactivate these names not in Fishbase
  {fishbase: [], inat: ["Tosanoides obama"]},
  {fishbase: [], inat: ["Suttonia kermadecensis"]},
  {fishbase: [], inat: ["Suttonia divaricata"]},
  {fishbase: [], inat: ["Amblyeleotris gymnocephalus"]},
  {fishbase: [], inat: ["Trimma finistrinum"]},
  {fishbase: [], inat: ["Rhinogobius nganfoensis"]},
  {fishbase: [], inat: ["Rhinogobius vinhensis"]},
  {fishbase: [], inat: ["Cryptocentroides argulus"]},
  {fishbase: [], inat: ["Pseudogobius melanosticta"]},
  {fishbase: [], inat: ["Gobiopsis liolepis"]},
  {fishbase: [], inat: ["Oxyurichthys zeta"]},
  {fishbase: [], inat: ["Dotsugobius bleekeri"]},
  {fishbase: [], inat: ["Hazeus diacanthus"]},
  {fishbase: [], inat: ["Gobioides broussonetii"]},
  {fishbase: [], inat: ["Egglestonichthys ulbubunitj"]},
  {fishbase: [], inat: ["Schismatogobius insignis"]},
  {fishbase: [], inat: ["Omobranchus fasciolaticeps"]},
  {fishbase: [], inat: ["Pseudocaranx georgianus"]},
  {fishbase: [], inat: ["Pseudocrenilabrus pyrrhocaudalis"]},
  {fishbase: [], inat: ["Thorichthys maculipinnis"]},
  {fishbase: [], inat: ["Cichlasoma nebuliferus"]},
  {fishbase: [], inat: ["Vieja bimaculata"]},
  {fishbase: [], inat: ["Australoheros autochthon"]},
  {fishbase: [], inat: ["Rocio spinosissima"]},
  {fishbase: [], inat: ["Cribroheros robertsoni"]},
  {fishbase: [], inat: ["Cribroheros longimanus"]},
  {fishbase: [], inat: ["Cribroheros alfari"]},
  {fishbase: [], inat: ["Cribroheros rostratus"]},
  {fishbase: [], inat: ["Cribroheros bussingi"]},
  {fishbase: [], inat: ["Cribroheros diquis"]},
  {fishbase: [], inat: ["Cribroheros altifrons"]},
  {fishbase: [], inat: ["Cribroheros rhytisma"]},
  {fishbase: [], inat: ["Kihnichthys ufermanni"]},
  {fishbase: [], inat: ["Rheoheros lentiginosus"]},
  {fishbase: [], inat: ["Darienheros calobrensis"]},
  {fishbase: [], inat: ["Maskaheros argenteus"]},
  {fishbase: [], inat: ["Maskaheros regani"]},
  {fishbase: [], inat: ["Teleocichla preta"]},
  {fishbase: [], inat: ["Oscura heterospila"]},
  {fishbase: [], inat: ["Rheoheros coeruleus"]},
  {fishbase: [], inat: ["Plectorhinchus caeruleonothus"]},
  {fishbase: [], inat: ["Plectorhinchus pica"]},
  {fishbase: [], inat: ["Percina apina"]},
  {fishbase: [], inat: ["Parupeneus heptacantha"]},
  {fishbase: [], inat: ["Pomadasys approximans"]},
  {fishbase: [], inat: ["Mullus barbatus"]},
  {fishbase: [], inat: ["Apogon infuscus"]},
  {fishbase: [], inat: ["Pristicon trimaculata"]},
  {fishbase: [], inat: ["Sphaeramia nematopterus"]},
  {fishbase: [], inat: ["Foa yamba"]},
  {fishbase: [], inat: ["Jaydia carinata"]},
  {fishbase: [], inat: ["Ozichthys albimaculosus"]},
  {fishbase: [], inat: ["Jaydia truncatus"]},
  {fishbase: [], inat: ["Diplodus sargus"]},
  {fishbase: [], inat: ["Dentex carpenteri"]},
  {fishbase: [], inat: ["Crenidens macracanthus"]},
  {fishbase: [], inat: ["Girella fremenvillei"]},
  {fishbase: [], inat: ["Scorpis hectori"]},
  {fishbase: [], inat: ["Scorpis boops"]},
  {fishbase: [], inat: ["Scorpis australis"]},
  {fishbase: [], inat: ["Monotaxis heterodon"]},
  {fishbase: [], inat: ["Nemadactylus macroptera"]},
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
  {fishbase: [], inat: ["Calliurichthys grossi"]},
  {fishbase: [], inat: ["Calliurichthys ogilbyi"]},
  {fishbase: [], inat: ["Foetorepus apricus"]},
  {fishbase: [], inat: ["Foetorepus grandoculis"]},
  {fishbase: [], inat: ["Pterosynchiropus occidentalis"]},
  {fishbase: [], inat: ["Repomucenus filamentosus"]},
  {fishbase: [], inat: ["Repomucenus keeleyi"]},
  {fishbase: [], inat: ["Repomucenus meridionalis"]},
  {fishbase: [], inat: ["Repomucenus sphinx"]},
  {fishbase: [], inat: ["Repomucenus sublaevis"]},
  {fishbase: [], inat: ["Repomucenus belcheri"]},
  {fishbase: [], inat: ["Stichaeus punctatus"]},
  {fishbase: [], inat: ["Heteropriacanthus carolinus"]},
  {fishbase: [], inat: ["Heteropriacanthus fulgens"]},
  {fishbase: [], inat: ["Monodactylus falciformes"]},
  {fishbase: [], inat: ["Olisthops brownii"]},
  {fishbase: [], inat: ["Sillago burra"]},
  {fishbase: [], inat: ["Uranoscopus terraereginae"]},
  {fishbase: [], inat: ["Hypopterus macroptera"]},
  {fishbase: [], inat: ["Aurigequula longispinis"]},
  {fishbase: [], inat: ["Psenes hillii"]},
  {fishbase: [], inat: ["Emmelichthys nitidus"]},
  {fishbase: [], inat: ["Matsubaraea fusiformis"]},
  {fishbase: [], inat: ["Barbus lepineyi"]},
  {fishbase: [], inat: ["Barbus moulouyensis"]},
  {fishbase: [], inat: ["Barbus pallaryi"]},
  {fishbase: [], inat: ["Barbus setivimensis"]},
  {fishbase: [], inat: ["Puntius euspilurus"]},
  {fishbase: [], inat: ["Dionda flavipinnis"]},
  {fishbase: [], inat: ["Scaphesthes tamusuiensis"]},
  {fishbase: [], inat: ["Anabarilius liui"]},
  {fishbase: [], inat: ["Squalidus gracilis"]},
  {fishbase: [], inat: ["Squalidus japonicus"]},
  {fishbase: [], inat: ["Sarcocheilichthys variegatus"]},
  {fishbase: [], inat: ["Physoschistura chulabhornae"]},
  {fishbase: [], inat: ["Orthrias angorae"]},
  {fishbase: [], inat: ["Beaufortia schaueri"]},
  {fishbase: [], inat: ["Beaufortia orbifolia"]},
  {fishbase: [], inat: ["Beaufortia micrantha"]},
  {fishbase: [], inat: ["Meuschenia scabra"]},
  {fishbase: [], inat: ["Aluterus abassai"]},
  {fishbase: [], inat: ["Mola tecta"]},
  {fishbase: [], inat: ["Pterois paucispinula"]},
  {fishbase: [], inat: ["Acanthostracion bucephalus"]},
  {fishbase: [], inat: ["Chilomycterus spinosus"]},
  {fishbase: [], inat: ["Scorpaenopsis insperata"]},
  {fishbase: [], inat: ["Scorpaena africana"]},
  {fishbase: [], inat: ["Scorpaena aculeata"]},
  {fishbase: [], inat: ["Sebastapistes mauritianus"]},
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
  {fishbase: [], inat: ["Doryrhamphus melanopleura"]},
  {fishbase: [], inat: ["Phyllopteryx dewysea"]},
  {fishbase: [], inat: ["Halicampus ensenadae"]},
  {fishbase: [], inat: ["Oncorhynchus formosanus"]},
  {fishbase: [], inat: ["Oncorhynchus masou"]},
  {fishbase: [], inat: ["Oncorhynchus rastrosus"]},
  {fishbase: [], inat: ["Oncorhynchus ishikawai"]},
  {fishbase: [], inat: ["Salvelinus alpinus"]},
  {fishbase: [], inat: ["Salvelinus leucomaenis"]},
  {fishbase: [], inat: ["Coregonus hubbsi"]},
  {fishbase: [], inat: ["Pseudoxiphophorus anzuetoi"]},
  {fishbase: [], inat: ["Pseudoxiphophorus jonesii"]},
  {fishbase: [], inat: ["Allodontichtys hubbsi"]},
  {fishbase: [], inat: ["Allodontichtys polylepis"]},
  {fishbase: [], inat: ["Allodontichtys tamazulae"]},
  {fishbase: [], inat: ["Ariosoma hemiaspidus"]},
  {fishbase: [], inat: ["Chaetostoma anomala"]},
  {fishbase: [], inat: ["Sciades felis"]},
  {fishbase: [], inat: ["Sciades leptaspis"]},
  {fishbase: [], inat: ["Sciades seemani"]},
  {fishbase: [], inat: ["Fragilaria construens binodis"]},
  {fishbase: [], inat: ["Chiloglanis devosi"]},
  {fishbase: [], inat: ["Chiloglanis kerioensis"]},
  {fishbase: [], inat: ["Pinnularia braunii amphicephala"]},
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
  {fishbase: [], inat: ["Alosa caspia"]},
  {fishbase: [], inat: ["Astyanax rutilus"]},
  {fishbase: [], inat: ["Gephyrocharax atricaudatus"]},
  {fishbase: [], inat: ["Saccoderma falcata"]},
  {fishbase: [], inat: ["Pygopristis denticulatus"]},
  {fishbase: [], inat: ["Myloplus zorroi"]},
  {fishbase: [], inat: ["Leporinus enyae"]},
  {fishbase: [], inat: ["Pterodiscus cookei"]},
  {fishbase: [], inat: ["Liza ordensis"]},
  {fishbase: [], inat: ["Mugil rammelsbergi"]},
  {fishbase: [], inat: ["Planiliza subviridis"]},
  {fishbase: [], inat: ["Plecoglossus altivelis"]},
  {fishbase: [], inat: ["Galaxias arcanus"]},
  {fishbase: [], inat: ["Galaxias mungadhan"]},
  {fishbase: [], inat: ["Argentina microphylla"]},
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
  {fishbase: [], inat: ["Monacoa niger"]},
  {fishbase: [], inat: ["Nansenia boreacrassicauda"]},
  {fishbase: [], inat: ["Dolicholagus longirosytis"]},
  {fishbase: [], inat: ["Platybelone argalus"]},
  {fishbase: [], inat: ["Tylosurus acus"]},
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
  {fishbase: [], inat: ["Atherinella pellosemion"]},
  {fishbase: [], inat: ["Menidia aculeatum"]},
  {fishbase: [], inat: ["Atherinosoma elongatum"]},
  {fishbase: [], inat: ["Austromenidia vegia"]},
  {fishbase: [], inat: ["Patagonia peregrinum"]},
  {fishbase: [], inat: ["Pseudomugil luminatus"]},
  {fishbase: [], inat: ["Porophryne erythrodactylus"]},
  {fishbase: [], inat: ["Kuiterichthys pietschi"]},
  {fishbase: [], inat: ["Antennarius steffifer"]},
  {fishbase: [], inat: ["Histrio acuminatus"]},
  {fishbase: [], inat: ["Chaunacops spinosus"]},
  {fishbase: [], inat: ["Lophiodon spilurus"]},
  {fishbase: [], inat: ["Pegasus tetrabelos"]},
  {fishbase: [], inat: ["Spinachia linnei"]},
  {fishbase: [], inat: ["Trachelochismus aestuarium"]},
  {fishbase: [], inat: ["Gouania lineata"]},
  {fishbase: [], inat: ["Nettorhamphos radula"]},
  {fishbase: [], inat: ["Dellichthys trnskii"]},
  {fishbase: [], inat: ["Gadus chalcogramma"]},
  {fishbase: [], inat: ["Hymenocephalus iwamotoi"]},
  {fishbase: [], inat: ["Trachyrinchus murray"]},
  {fishbase: [], inat: ["Trachyrinchus trachyrhynchus"]},
  {fishbase: [], inat: ["Trachyrinchus murrayi"]},
  {fishbase: [], inat: ["Merluccius gayi"]}
]

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

