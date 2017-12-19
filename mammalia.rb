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

#These are intentional discrepancies between IUCN and whats on iNat
discrepancies = [
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
#bats are still a mess - punting
{iucn: ["Dermanura anderseni", "Dermanura azteca", "Dermanura cinerea", "Dermanura gnoma", "Dermanura tolteca", "Chaerephon aloysiisabaudiae", "Chaerephon ansorgei", "Chaerephon bemmeleni", "Chaerephon bivittatus", "Chaerephon bregullae", "Chaerephon chapini", "Chaerephon gallagheri", "Chaerephon jobensis", "Chaerephon johorensis", "Chaerephon major", "Chaerephon nigeriae", "Chaerephon plicatus", "Chaerephon pumilus", "Chaerephon russatus", "Chaerephon solomonis", "Chaerephon tomensis", "Diclidurus isabella", "Hipposideros commersoni", "Mops brachypterus", "Mops condylurus", "Mops congicus", "Mops demonstrator", "Mops midas", "Mops mops", "Mops nanulus", "Mops niangarae", "Mops niveiventer", "Mops petersoni", "Mops sarasinorum", "Mops spurrelli", "Mops thersites", "Mops trevori", "Hypsugo anthonyi", "Pipistrellus hesperus", "Hypsugo joffrei", "Hypsugo kitcheneri", "Hypsugo lophurus", "Hypsugo macrotis", "Pipistrellus subflavus", "Rhogeessa alleni", "Rousettus lanosus", "Scotonycteris ophiodon", "Austronomus australis", "Mops leucostigma", "Triaenops rufus", "Neoromicia matroka", "Nycticeinops schlieffeni", "Hypsugo vordermanni", "Lissonycteris angolensis", "Hypsugo savii", "Miniopterus africanus", "Neoromicia brunnea", "Neoromicia capensis", "Neoromicia flavescens", "Neoromicia guineensis", "Neoromicia helios", "Neoromicia melckorum", "Neoromicia nana", "Neoromicia rendalli", "Neoromicia somalica", "Neoromicia tenuipinnis", "Neoromicia zuluensis", "Austronomus kuboriensis", "Natalus espiritosantensis", "Dermanura rosenbergi", "Neoromicia malagasyensis", "Neoromicia robertsi", "Neoromicia roseveari", "Chaerephon atsinanana", "Mops bakarii", "Mormopterus lumsdenae", "Mormopterus kitcheneri", "Mormopterus halli", "Mormopterus ridei", "Mormopterus cobourgianus", "Myotis nyctor", "Rhinolophus xinanzhongguoensis", "Dermanura glauca", "Dermanura bogotensis", "Dermanura phaeotis", "Rhinolophus belligerator", "Rhinolophus mcintyrei", "Rhinolophus proconsulis", "Rhinolophus tatar", "Rhinolophus indorouxii", "Rhinolophus microglobosus", "Epomophorus minor", "Scotophilus andrewreborii", "Scotophilus ejetai", "Scotophilus livingstonii", "Scotophilus trujilloi", "Murina bicolor", "Murina gracilis", "Murina recondita", "Murina jaintiana", "Murina pluvialis", "Hypsugo bemainty", "Otonycteris leucophaea", "Myotis secundus", "Myotis soror", "Submyotodon latirostris", "Myotis borneoensis", "Myotis federatus", "Myotis peytoni", "Peropteryx pallidoptera", "Cynomops milleri", "Eumops wilsoni", "Eumops nanus", "Pteronotus mesoamericanus", "Pteronotus rubiginosus", "Molossus bondae", "Promops davisoni", "Chiroderma vizzotoi", "Anoura cadenai", "Artibeus schwartzi", "Micronycteris buriri", "Micronycteris giovanniae", "Lophostoma occidentalis", "Lonchophylla peracchii", "Thyroptera wynneae", "Eptesicus taddeii", "Lasiurus salinae", "Myotis diminutus", "Myotis izecksohni", "Myotis lavali", "Rhogeessa bickhami", "Rhogeessa menchuae", "Rhogeessa velilla", "Vampyrodes major", "Sturnira burtonlimi", "Sturnira koopmanhilli", "Sturnira perla", "Platyrrhinus incarum", "Platyrrhinus angustirostris", "Platyrrhinus aquilus", "Platyrrhinus nitelinea", "Neoromicia isabella", "Dermanura watsoni"], inat: ["Myotis phanluongi", "Pipistrellus savii", "Pipistrellus nanus", "Pipistrellus rendalli", "Pipistrellus capensis", "Pipistrellus guineensis", "Pipistrellus tenuipinnis", "Pipistrellus brunneus", "Pipistrellus zuluensis", "Pipistrellus isabella", "Pipistrellus somalicus", "Pipistrellus roseveari", "Pipistrellus stanleyi", "Pipistrellus anthonyi", "Eptesicus malagasyensis", "Eptesicus matroka", "Perimyotis subflavus", "Parastrellus hesperus", "Plecotus gaisleri", "Pipistrellus lophurus", "Pipistrellus kitcheneri", "Pipistrellus joffrei", "Pipistrellus macrotis", "Pipistrellus vordermanni", "Pipistrellus helios", "Pipistrellus robertsi", "Pipistrellus lanzai", "Pipistrellus bemainty", "Scotophilus alvenslebeni", "Nycticeinops schlieffenii", "Nyctophilus corbeni", "Nyctophilus major", "Glauconycteris atra", "Tadarida australis", "Tadarida pumila", "Tadarida condylura", "Tadarida nigeriae", "Tadarida plicata", "Tadarida thersites", "Tadarida nanula", "Tadarida jobensis", "Tadarida ansorgei", "Tadarida aloysiisabaudiae", "Tadarida major", "Tadarida demonstrator", "Tadarida russata", "Tadarida spurrelli", "Tadarida bregullae", "Tadarida leucostigma", "Tadarida midas", "Tadarida tomensis", "Tadarida trevori", "Tadarida chapini", "Tadarida brachyptera", "Tadarida bakarii", "Baeodon alleni", "Tadarida johorensis", "Tadarida kuboriensis", "Tadarida mops", "Tadarida sarasinorum", "Tadarida solomonis", "Molossus barnesi", "Harpiocephalus mordax", "Tadarida bemmeleni", "Tadarida bivittata", "Tadarida congica", "Tadarida gallagheri", "Tadarida jobimena", "Tadarida niangarae", "Tadarida niveiventer", "Tadarida petersoni", "Tadarida atsinanana", "Artibeus phaeotis", "Artibeus watsoni", "Artibeus aztecus", "Artibeus toltecus", "Miniopterus oceanensis", "Artibeus cinereus", "Natalus macrourus", "Natalus lanatus", "Miniopterus mossambicus", "Miniopterus fuliginosus", "Miniopterus villiersi", "Artibeus glaucus", "Artibeus incomitatus", "Artibeus rosenbergii", "Lophostoma aequatorialis", "Lophostoma yasuni", "Artibeus anderseni", "Sturnira thomasi", "Artibeus gnomus", "Pteropus yapensis", "Pteropus argentatus", "Pteropus brunneus", "Diclidurus isabellus", "Myonycteris angolensis", "Stenonycteris lanosus", "Scotonycteris bergmansi", "Scotonycteris occidentalis", "Casinycteris ophiodon", "Dobsonia magna", "Pteropus pilosus", "Pteropus tokudae", "Pteropus insularis", "Rhinolophus geoffroyi", "Rhinolophus willardi", "Hipposideros commersonii", "Hipposideros nicobarulae", "Hipposideros cryptovalorona", "Rhinolophus nippon", "Rhinolophus mabuensis", "Rhinolophus horaceki", "Rhinolophus kahuzi", "Triaenops menamena", "Coelops hirsutus", "Paracoelops megalotis"] }
]

leftovers = discrepancies.map{|row| row[:iucn]}.flatten - iucn.map{|row| row["scientific_name"]}
if leftovers.count > 0
  puts "These are no longer in the IUCN"
  leftovers.each do |name|
    puts "\t" + name
  end
end

added = (discrepancies.map{|row| row[:inat]}.flatten.uniq - discrepancies.map{|row| row[:iucn]}.flatten.uniq) &  iucn.map{|row| row["scientific_name"]}
if added.count > 0
  puts "These have been added to the IUCN"
  added.each do |name|
    puts "\t" + name
  end
end

# These are species in iNat, not in IUCN
res = []
not_in_iucn = ( inat_names.map{ |row| row[:name] } - iucn.map{|row| row["scientific_name"]} )
if not_in_iucn.count > 0
  puts "These are species in iNat, not in IUCN..."
  not_in_iucn.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:inat]}.flatten.include? name
      puts "\t" + name
      res << name
    end
  end
end
#build swaps from these to indicate how these taxa should be dealt with
swaps = Hash.new

# These are species in IUCN, not in iNat
res = []
not_in_inat = ( iucn.map{|row| row["scientific_name"]} - inat_names.map{ |row| row[:name] } )
if not_in_inat.count > 0
  puts "These are species in RD, not in iNat..."
  not_in_inat.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:iucn]}.flatten.include? name
      #ignore taxa accounted for by the above swaps
      unless swaps.values.include? name
        puts "\t" + name + "\t" + iucn.select{|a| a["scientific_name"] == name }[0]["order_name"].downcase.capitalize
        res << name if iucn.select{|a| a["scientific_name"] == name }[0]["order_name"].downcase.capitalize == "Chiroptera"
      end
    end
  end
end








