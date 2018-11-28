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
  {fishbase: [], inat: ["Rhizosomichthys totae"]},
  {fishbase: [], inat: ["Aethotaxis mitopteryx"]},
  {fishbase: [], inat: ["Leucos aula"]},
  {fishbase: [], inat: ["Merluccius gayi"]},
  {fishbase: [], inat: ["Neotrygon trigonoides"]},
  {fishbase: [], inat: ["Micropterus haiaka"]},
  {fishbase: [], inat: ["Stegastes marginatus"]},
  {fishbase: [], inat: ["Pomacentrus maafu"]},
  {fishbase: [], inat: ["Sirembo amaculata"]},
  {fishbase: [], inat: ["Sirembo wami"]},
  {fishbase: [], inat: ["Pomacentrus micronesicus"]},
  {fishbase: [], inat: ["Altrichthys alelia"]},
  {fishbase: [], inat: ["Tylosurus acus"]},
  {fishbase: [], inat: ["Barbodes semifasciolatus"]},
  {fishbase: [], inat: ["Centrolabrus melanocercus"]},
  {fishbase: ["Trachinocephalus myops"], inat: ["Trachinocephalus trachinus", "Trachinocephalus myops", "Trachinocephalus gauguini"]}, #split
  #Explicit deviations for fishbase
  {fishbase: [], inat: ["Stomias boa"]} #https://www.inaturalist.org/flags/283439
  {fishbase: ["Pseudoxiphophorus obliquus"], inat: ["Heterandria obliqua"]}, #Fishbase has it in Pseudoxiphophorus and departs from the API with Pseudoxiphophorus anzuetoi	(Rosen & Bailey, 1979).Pseudoxiphophorus bimaculatus,Pseudoxiphophorus cataractae,Pseudoxiphophorus diremptus,Pseudoxiphophorus jonesii,Pseudoxiphophorus litoperas
  {fishbase: ["Hippocampus alatus", "Hippocampus spinosissimus"], inat: ["Hippocampus spinosissimus"]}, # via IUCN seahorse group
  {fishbase: ["Hippocampus procerus","Hippocampus whitei"], inat: ["Hippocampus whitei"]}, # via IUCN seahorse group
  {fishbase: ["Hippocampus waleananus","Hippocampus satomiae"], inat: ["Hippocampus satomiae"]}, # via IUCN seahorse group
  {fishbase: ["Hippocampus biocellatus","Hippocampus trimaculatus"], inat: ["Hippocampus trimaculatus", "Hippocampus planifrons", "Hippocampus dahli"]}, # via IUCN seahorse group
  {fishbase: ["Hippocampus fuscus","Hippocampus borboniensis","Hippocampus kuda"], inat: ["Hippocampus kuda"]}, # via IUCN seahorse group
  {fishbase: ["Cheilinus fasciatus"], inat: ["Cheilinus quinquecinctus","Cheilinus fasciatus"]},
  {fishbase: ["Chrysiptera brownriggii"], inat: ["Chrysiptera leucopoma","Chrysiptera brownriggii"]},
  {fishbase: ["Poecilia sphenops"], inat: ["Poecilia thermalis","Poecilia sphenops"]},
  {fishbase: ["Synodus variegatus"], inat: ["Synodus houlti", "Synodus variegatus"]},
  {fishbase: ["Antennatus coccineus"], inat: ["Antennarius nummifer","Antennatus coccineus"]},
  {fishbase: ["Lethrinus lentjan"], inat: ["Lethrinus punctulatus","Lethrinus lentjan"]},
  {fishbase: ["Pagrus auratus"], inat: ["Chrysophrys auratus"]},
  {fishbase: ["Synchiropus rameus"], inat: ["Orbonymus rameus"]},      #cof uses Orbonymus
  {fishbase: ["Crenimugil seheli"], inat: ["Moolgarda seheli"]},          #cof uses Moolgarda
  {fishbase: ["Helotes sexlineatus"], inat: ["Pelates sexlineatus"]},     #see https://www.inaturalist.org/taxon_changes/27850
  {fishbase: ["Schistura denisoni"], inat: ["Nemacheilus denisoni"]},
  {fishbase: ["Planiliza haematocheila"], inat: ["Liza haematocheila"]},
  {fishbase: ["Dajaus monticola"], inat: ["Agonostomus monticola"]},
  {fishbase: ["Chelon ramada"], inat: ["Liza ramada"]},
  {fishbase: ["Chelon auratus"], inat: ["Liza aurata"]},
  {fishbase: ["Pelates octolineatus"], inat: ["Helotes octolineatus"]},
  {fishbase: ["Nosferatu bartoni"], inat: ["Herichthys bartoni"]},      # https://www.inaturalist.org/flags/248128
  {fishbase: ["Nosferatu labridens"], inat: ["Herichthys labridens"]},
  {fishbase: ["Nosferatu molango"], inat: ["Herichthys molango"]},
  {fishbase: ["Nosferatu pame"], inat: ["Herichthys pame"]},
  {fishbase: ["Nosferatu pratinus"], inat: ["Herichthys pantostictus"]}, # "Nosferatu pantostictus" is in Fishbase but not the API
  {fishbase: ["Nosferatu steindachneri"], inat: ["Herichthys steindachneri"]},
  {fishbase: ["Tetraodon barbatus"], inat: ["Pao barbatus"]} #https://www.inaturalist.org/flags/273964
  # newly discovered not yet in fishbase:
  {fishbase: [], inat: ["Dellichthys trnskii"]},
  {fishbase: [], inat: ["Trachelochismus aestuarium"]},
  {fishbase: [], inat: ["Kuiterichthys pietschi"]}, #https://www.inaturalist.org/flags/283371
  {fishbase: [], inat: ["Chaunacops spinosus"]} #https://www.inaturalist.org/flags/283372
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
swaps2 = []
# These are species in iNat, not in Fishbase
not_in_fishbase = ( inat_names.map{ |row| row[:name] } - fishbase.map{|row| row[:name]} )
if not_in_fishbase.count > 0
  puts "These are species in iNat, not in Fishbase..."
  not_in_fishbase.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:inat]}.flatten.include? name
      if syn = synkey(name, fishbase_synonyms, fishbase)
        swaps << {in: name, out: syn}
        #puts "{in: \"" + name + "\", out: \"" + syn + "\"},"
      else
        puts "{in: \"" + name + "\", out: \"\"},"
        swaps2 << {in: name, out: ""}
      end
    end
  end
end


swaps2 #flag them

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

leftovers = ["Rhinogobius nganfoensis", "Rhinogobius vinhensis", "Pseudogobius melanosticta", "Cryptocentroides argulus", "Oxyurichthys zeta", "Hazeus diacanthus", "Egglestonichthys ulbubunitj", "Dentex carpenteri", "Teleocichla preta", "Pseudocaranx georgianus", "Pomadasys approximans", "Mullus barbatus", "Scorpis hectori", "Scorpis boops", "Scorpis australis", "Ozichthys albimaculosus", "Nemadactylus carponotatus", "Nemadactylus concinnus", "Cheilodactylus antonii", "Cheilodactylus aspersus", "Cheilodactylus carmichaelis", "Parascolopsis rufomaculata", "Eucinostomus californiensis", "Ditrema temminckii", "Gobiomorphus gobiodes", "Microdesmus longispinnis", "Boroda malua", "Pseudocalliurichthys goodladi", "Repomucenus sublaevis", "Repomucenus belcheri", "Neosynchiropus marbacescui", "Bathycallionymus bifilum", "Bathycallionymus kailolae", "Calliurichthys afilum", "Calliurichthys australis", "Calliurichthys ogilbyi", "Foetorepus apricus", "Foetorepus grandoculis", "Pterosynchiropus occidentalis", "Repomucenus filamentosus", "Repomucenus keeleyi", "Repomucenus meridionalis", "Stichaeus punctatus", "Heteropriacanthus carolinus", "Heteropriacanthus fulgens", "Olisthops brownii", "Sillago burra", "Uranoscopus terraereginae", "Hypopterus macroptera", "Aurigequula longispinis", "Psenes hillii", "Matsubaraea fusiformis", "Emmelichthys nitidus", "Puntius euspilurus", "Sarcocheilichthys variegatus", "Dionda flavipinnis", "Anabarilius liui", "Scaphesthes tamusuiensis", "Physoschistura chulabhornae", "Orthrias angorae", "Aluterus abassai", "Meuschenia scabra", "Chilomycterus spinosus", "Acanthostracion bucephalus", "Scorpaena africana", "Scorpaena aculeata", "Platycephalus australis", "Onigocia macrocephala", "Platycephalus angustus", "Sebastolobus varispinis", "Trachyscorpia cristulata", "Liparis makinoana", "Liparis madrensis", "Paraliparis copei", "Notoliparis stewarti", "Kanekonia leichhardti", "Hoplichthys mimaseanus", "Doryrhamphus excisus", "Halicampus ensenadae", "Allodontichtys hubbsi", "Allodontichtys polylepis", "Allodontichtys tamazulae", "Chaetostoma anomala", "Oreoglanis hponkanensis", "Olyra taquara", "Ariosoma hemiaspidus", "Etropus delsmani", "Monolene maculipina", "Engyprosopon osculum", "Brachirus breviceps", "Brachirus fitzroiensis", "Pardachirus rautheri", "Pseudaesopia callizona", "Symphurus sitgmosus", "Paraplagusia bleekeri", "Clupea pallasii", "Strongylura notata", "Platybelone argalus", "Cheilopogon pinnatibarbatus", "Hyporhamphus roberti", "Gephyrocharax atricaudatus", "Saccoderma falcata", "Pygopristis denticulatus", "Leporinus enyae", "Pterodiscus cookei", "Menidia aculeatum", "Menidia alchichica", "Menidia ferdebueni", "Menidia labarcae", "Menidia letholepis", "Menidia promelas", "Menidia squamata", "Menidia bartoni", "Menidia charari", "Menidia riojai", "Atherinella pellosemion", "Atherinosoma elongatum", "Pseudomugil luminatus", "Galaxias arcanus", "Galaxias mungadhan", "Galaxias oliros", "Galaxias aequipinnis", "Galaxias brevissimus", "Galaxias gunaikurnai", "Galaxias lanceolatus", "Galaxias longifundus", "Galaxias mcdowalli", "Galaxias supremus", "Galaxias tantangara", "Galaxias terenasus", "Mallotus philippinensis", "Dolicholagus longirosytis", "Porophryne erythrodactylus", "Antennarius steffifer", "Argentina tapetodes", "Kuiterichthys pietschi", "Chaunacops spinosus"]
taxon_id = 1
leftovers.each do |name|
  unless t = Taxon.where("name = ? AND is_active = true AND rank IN ('genus','tribe','species') AND ancestry LIKE (?)", name, "%/#{taxon_id}/%").first
    puts name
    next
  end
  if flag = Flag.where(flaggable_id: t.id, flaggable_type: 'Taxon', resolved: false).first
    puts "flag exists for #{t.id}"
    next
  end
  #create flag
  flag = Flag.new(flag: "taxon (maybe?) not in Fishbase", user_id: 477, flaggable_id: t.id, flaggable_type: 'Taxon', resolved: false)
  if flag.save!
    puts flag.id
    Comment.create(parent_type: "Flag", parent_id: flag.id, user_id: 477, body: "iNat syncs with Fishbase using the 3rd party https://fishbase.ropensci.org/ API, which can be a bit out of sync with Fishbase so this could be out of date. But this taxon doesn't appear to be in the fishbase.ropensci.org API and thus likeley not in Fishbase. Is it actually in Fishbase, an error/duplicate, or a legit taxon that should be added as a deviation from Fishbase?")
  end
end



#add news
#swaps

gen = ["Caraibops","Kaperangus","Parascombrops","Phycocharax","Pseudorestias","Euryochus","Pseudoqolus","Malihkaia","Anoptoplacus","Pseudoxiphophorus","Samaretta","Barbourichthys","Amamiichthys","Cymatognathus","Potamoglanis"]
gen.each do |row|
  fam = not_in_inat.select{|a| a[:name].split[0] == row}.first[:family]
  puts [row,fam].join(", ")
end

taxon_id = 1
not_in_inat.each do |row|
  name = row[:name]
  parent = name.split[0]
  puts name
  unless parent_taxon = Taxon.where("name = ? AND is_active = true AND rank = 'genus' AND (ancestry LIKE (?) OR ancestry LIKE (?))", parent, "%/#{taxon_id}/%", "%/#{taxon_id}").first
    puts "\t\t\tmissing"
    next
  end
  unless t = Taxon.where("is_active = true AND name = ? AND rank = 'species' AND ancestry LIKE (?)", name, "%/#{taxon_id}/%").first
    if t = Taxon.where("is_active = false AND name = ? AND rank = 'species' AND ancestry LIKE (?)", name, "%/#{taxon_id}/%").first
      puts "\t\t\tactivating #{name}"
      t.is_active = true
      t.skip_locks = true
      t.skip_complete = true
      puts "issue" unless t.save!
    else
      puts "\t\t\tcreating #{name}"
      t = Taxon.new(name: name, rank: "species", is_active: true)
      t.parent = parent_taxon
      t.skip_locks = true
      t.skip_complete = true
      puts "issue" unless t.save!
    end
  end
end



#swap sp
taxon_id2 =1
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
  
  if tc = TaxonChange.where(taxon_id: output.id, committed_on: nil).first #draf exists
    if tct = TaxonChangeTaxon.where(taxon_id: input.id, taxon_change_id: tc.id).first
      putting << tc.id
      next
    end
  end
  tc = TaxonChange.new(
        description: "swapped in Fisbase",
        taxon_id: output.id,
        source_id: 12552,
        user_id: 477,
        type: "TaxonSwap",
        committed_on: nil,
        change_group: "10_2018 Fish update",
        committer_id: nil
  )
  tc.save(:validate => false)
  tct = TaxonChangeTaxon.create(taxon_id: input.id, taxon_change_id: tc.id)
  puts "made taxon change for #{input.name} and #{output.name}"
end

#commit the taxon changes
loarie = User.find(477)
tcts = TaxonChangeTaxon.joins(:taxon, :taxon_change).where("taxon_changes.committed_on IS NULL AND taxon_changes.change_group = '10_2018 Fish update'").pluck(:taxon_change_id)
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


