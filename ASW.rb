###
#
# This ruby script loops compares a ASW (by scraping 
# http://research.amnh.org/vz/herpetology/amphibia/index.php/)
# with Amphibian extant species on iNaturalist
#
###

require 'uri'
require 'csv'
require 'net/http'
require 'json'
require 'nokogiri' 
require 'open-uri'

#The approach here is to scrape ASW by looping through countries - not idea, but easier/faster than traversing the taxonomy
puts "Scraping ASW..."
key = {614=>"Afganistan",389=>"Albania",445=>"Algeria",388=>"Andorra",302=>"Angola",153=>"Anguilla",182=>"Antigua and Barbuda",414=>"Argentina",305=>"Armenia",541=>"Aruba",555=>"Australia",584=>"Austria",219=>"Azerbaijan",527=>"Bahamas",374=>"Bahrain",191=>"Bangladesh",457=>"Barbados",232=>"Belarus",477=>"Belgium",440=>"Belize",273=>"Benin",569=>"Bermuda",593=>"Bhutan",333=>"Bolivia",294=>"Bonaire",607=>"Bosnia and Herzegovina",442=>"Botswana",194=>"Brazil",347=>"Brunei",450=>"Bulgaria",478=>"Burkina Faso",373=>"Burundi",269=>"Cambodia",471=>"Cameroon",563=>"Canada",588=>"Cape Verde",188=>"Cayman Islands",521=>"Central African Republic",583=>"Chad",253=>"Chile",505=>"China, People's Republic of",599=>"Colombia",266=>"Comoros",160=>"Congo, Democratic Republic of the",606=>"Congo, Republic of the",260=>"Costa Rica",436=>"Croatia",330=>"Cuba",303=>"Curaçao",564=>"Cyprus",520=>"Czech Republic",386=>"Denmark",321=>"Djibouti",204=>"Dominica",419=>"Dominican Republic",367=>"East Timor",200=>"Ecuador",554=>"Egypt",534=>"El Salvador",162=>"Equatorial Guinea",301=>"Eritrea",508=>"Estonia",163=>"Ethiopia",585=>"Fiji",581=>"Finland",262=>"France",482=>"French Guiana",551=>"Gabon",601=>"Gambia",611=>"Georgia",472=>"Germany",316=>"Ghana",243=>"Greece",245=>"Grenada",514=>"Guadeloupe",490=>"Guam",509=>"Guatemala",155=>"Guinea",307=>"Guinea-Bissau",161=>"Guyana",486=>"Haiti",310=>"Honduras",278=>"Hungary",387=>"Iles des Saintes",441=>"India",166=>"Indonesia",349=>"Iran",223=>"Iraq",513=>"Ireland",206=>"Israel",365=>"Italy",544=>"Ivory Coast",203=>"Jamaica",196=>"Japan",590=>"Jordan",362=>"Kazakhstan",552=>"Kenya",494=>"Korea, Democratic People's Republic (North)",537=>"Korea, Republic of (South)",573=>"Kyrgyzstan",435=>"La Desirade",451=>"Laos",181=>"Latvia",454=>"Lebanon",589=>"Lesotho",600=>"Liberia",491=>"Libya",498=>"Liechtenstein",561=>"Lithuania",344=>"Luxembourg",556=>"Macedonia",208=>"Madagascar",187=>"Malawi",267=>"Malaysia",190=>"Maldives",202=>"Mali",210=>"Malta",352=>"Martinique",574=>"Mauritania",205788=>"Mauritius",251=>"Mayotte",525=>"Mexico",549=>"Moldova",480=>"Monaco",277=>"Mongolia",343=>"Montenegro",341=>"Montserrat",424=>"Morocco",400=>"Mozambique",375=>"Myanmar",444=>"Namibia",392=>"Nepal",193=>"Netherlands",613=>"New Caledonia",370=>"New Zealand",312=>"Nicaragua",235=>"Niger",174=>"Nigeria",562=>"Norway",511=>"Oman",283=>"Pakistan",582=>"Palau",492=>"Panama",568=>"Papua New Guinea",432=>"Paraguay",167=>"Peru",591=>"Philippines",540=>"Poland",175=>"Portugal",497=>"Puerto Rico",378=>"Reunion",241=>"Romania",578=>"Russia",272=>"Rwanda",288=>"Saba",533=>"Saint Helena",239=>"Saint Kitts and Nevis",280=>"Saint Lucia",518=>"Saint Vincent and the Grenadines",270=>"Samoa",248=>"San Marino",597=>"Sao Tome and Principe",306=>"Saudi Arabia",617=>"Senegal",185=>"Serbia",577=>"Seychelles",506=>"Sierra Leone",461=>"Singapore",323=>"Slovakia",438=>"Slovenia",244123=>"Solomon Islands",393=>"Somalia",337=>"South Africa",231=>"South Moluccas",363=>"South Sudan",332=>"Spain",502=>"Sri Lanka",615=>"Sudan",173=>"Surinam",437=>"Swaziland",150=>"Sweden",335=>"Switzerland",495=>"Syria",448=>"Taiwan",325=>"Tajikistan",358=>"Tanzania",456=>"Thailand",545=>"Togo",281=>"Trinidad and Tobago",425=>"Tunisia",183=>"Turkey",309=>"Turkmenistan",324=>"Turks and Caicos Islands",592=>"Uganda",238=>"Ukraine",460=>"United Arab Emirates",559=>"United Kingdom",603=>"United States of America",274=>"Uruguay",484=>"Uzbekistan",515=>"Vanuatu",609=>"Venezuela",236=>"Vietnam",384=>"Virgin Islands, British",322=>"Virgin Islands, U.S.",300=>"Western Sahara",371=>"Yemen",499=>"Zambia",366=>"Zimbabwe"}
rev_key = key.invert
external_taxa = []
key.each do |code,country|
  file="http://research.amnh.org/vz/herpetology/amphibia/content/search?country=#{code}"
  page = Nokogiri::HTML(open(file))   
  records = page.css('div.Species a')
  records.each do |record|
    name = record.text.gsub("\n","").strip.sub(/\([^\)]*\)/, '').split[0..1].join(" ").gsub("\"","")
    already_included = external_taxa.map{|a| a[:name] == name}
    if already_included.any?
      index = already_included.index(true)
      external_taxa[index][:countries] << code
    else
      url = "http://research.amnh.org"+record.attributes["href"].value
      ancestry = record.attributes["href"].value.gsub("/vz/herpetology/amphibia/","").split("/")[0..-2]
      external_taxa << {name: name, url: url, ancestry: ancestry, rank: "species", countries: [code]}
    end
  end
end

external_taxa.each do |row|
  base_url = row[:url]
  base_ancestry = row[:ancestry]
  row[:ancestry].each do |ancestor|
    next if ancestor == "Amphibia"
    unless external_taxa.map{|a| a[:name]}.include? ancestor
      if ["Anura", "Caudata", "Gymnophiona"].include? ancestor
        rank = "order"
      elsif /inae$/ === ancestor
        rank = "subfamily"
      elsif /idae$/ === ancestor
        rank = "family"
      elsif /idea$/ === ancestor
        rank = "superfamily"
      else
        rank = "genus"
      end
      new_ancestry = base_ancestry[0..(base_ancestry.index(ancestor)-1)]
      new_url = "http://research.amnh.org/vz/herpetology/amphibia/"+new_ancestry.join("/")
      external_taxa << {name: ancestor, url: new_url, ancestry: new_ancestry, rank: rank, countries: nil}
    end
  end
end
external_taxa << {name: "Amphibia", url: "http://research.amnh.org/vz/herpetology/amphibia/Amphibia", ancestry: nil, rank: "class", countries: nil}




# Use the iNat API to find all species descending from the Amphibia root
puts "Using the iNat API to find all species descending from the Amphibia root..."
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

# Hardcode the inat_taxon id for class Amphibia
root_taxon_id = 20978
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

#These are intentional discrepancies between ASW and whats on iNat
discrepancies = [
  #typos/ommissions from the ASW API
  {asw: ["Ichthophis cardamomensis"], inat: ["Ichthyophis cardamomensis"]}, #typo
  {asw: ["Ichthophis catlocensis"], inat: ["Ichthyophis catlocensis"]}, #typo
  {asw: ["Ichthophis chaloensis"], inat: ["Ichthyophis chaloensis"]}, #typo
  {asw: [], inat: ["Dendropsophus nekronastes"]}, #missing from aws api
  {asw: [], inat: ["Hylodes caete"]}, #missing from aws api
  {asw: [], inat: ["Ameerega munduruku"]}, #missing from aws api
  #split in ASW
  {asw: ["Aneides iecanus","Aneides niger","Aneides flavipunctatus"], inat: ["Aneides flavipunctatus"]},
  {asw: ["Desmognathus aureatus","Desmognathus melanius","Desmognathus marmoratus"], inat: ["Desmognathus marmoratus"]},
  {asw: ["Desmognathus auriculatus","Desmognathus valentinei"], inat: ["Desmognathus auriculatus"]},
  {asw: ["Pseudotriton diastictus","Pseudotriton montanus"], inat: ["Pseudotriton montanus"]},
  {asw: ["Trachycephalus typhonius","Trachycephalus macrotis","Trachycephalus quadrangulum","Trachycephalus vermiculatus"], inat: ["Trachycephalus typhonius"]},
  {asw: ["Eurycea quadridigitata","Eurycea hillisi","Eurycea paludicola","Eurycea sphagnicola"], inat: ["Eurycea quadridigitata"]},
  {asw: ["Eurycea spelaea", "Eurycea nerea", "Eurycea braggi"], inat: ["Eurycea spelaea"]},  
  {asw: ["Lissotriton graecus","Lissotriton vulgaris"], inat: ["Lissotriton vulgaris"]},
  {asw: ["Smilisca manisorum","Smilisca baudinii"], inat: ["Smilisca baudinii"]},
  #swap  
  {asw: ["Dryophytes andersonii"], inat: ["Hyla andersonii"]},
  {asw: ["Dryophytes arboricola"], inat: ["Hyla arboricola"]},
  {asw: ["Dryophytes arenicolor"], inat: ["Hyla arenicolor"]} ,
  {asw: ["Dryophytes avivoca"], inat: ["Hyla avivoca"]},
  {asw: ["Dryophytes bocourti"], inat: ["Hyla bocourti"]},
  {asw: ["Dryophytes chrysoscelis"], inat: ["Hyla chrysoscelis"]},
  {asw: ["Dryophytes cinereus"], inat: ["Hyla cinerea"]},
  {asw: ["Dryophytes euphorbiaceus"], inat: ["Hyla euphorbiacea"]},
  {asw: ["Dryophytes eximius"], inat: ["Hyla eximia"]},
  {asw: ["Dryophytes femoralis"], inat: ["Hyla femoralis"]},
  {asw: ["Dryophytes gratiosus"], inat: ["Hyla gratiosa"]},
  {asw: ["Dryophytes immaculatus"], inat: ["Hyla immaculata"]},
  {asw: ["Dryophytes japonicus"], inat: ["Hyla japonica"]},
  {asw: ["Dryophytes plicatus"], inat: ["Hyla plicata"]},
  {asw: ["Dryophytes squirellus"], inat: ["Hyla squirella"]},
  {asw: ["Dryophytes versicolor"], inat: ["Hyla versicolor"]},
  {asw: ["Dryophytes walkeri"], inat: ["Hyla walkeri"]},
  {asw: ["Dryophytes wrightorum"], inat: ["Hyla wrightorum"]},
  {asw: ["Hyliola cadaverina"], inat: ["Pseudacris cadaverina"]},
  {asw: ["Hyliola hypochondriaca"], inat: ["Pseudacris hypochondriaca"]},
  {asw: ["Hyliola regilla"], inat: ["Pseudacris regilla"]},
  {asw: ["Hyliola sierra"], inat: ["Pseudacris sierra"]},
  #These are species in Amphibians Species of the World that are known to be extinct and are thus ignored...
  {asw: ["Atelopus vogli"], inat: []},
  {asw: ["Incilius periglenes"], inat: []},
  {asw: ["Craugastor chrysozetetes"], inat: []},
  {asw: ["Nannophrys guentheri"], inat: []},
  {asw: ["Rheobatrachus silus"], inat: []},
  {asw: ["Rheobatrachus vitellinus"], inat: []},
  {asw: ["Taudactylus diurnus"], inat: []},
  {asw: ["Phrynomedusa fimbriata"], inat: []},
  {asw: ["Lithobates fisheri"], inat: []},
  {asw: ["Pseudophilautus adspersus"], inat: []},
  {asw: ["Pseudophilautus dimbullae"], inat: []},
  {asw: ["Pseudophilautus eximius"], inat: []},
  {asw: ["Pseudophilautus extirpo"], inat: []},
  {asw: ["Pseudophilautus halyi"], inat: []},
  {asw: ["Pseudophilautus hypomelas"], inat: []},
  {asw: ["Pseudophilautus leucorhinus"], inat: []},
  {asw: ["Pseudophilautus maia"], inat: []},
  {asw: ["Pseudophilautus malcolmsmithi"], inat: []},
  {asw: ["Pseudophilautus nanus"], inat: []},
  {asw: ["Pseudophilautus nasutus"], inat: []},
  {asw: ["Pseudophilautus oxyrhynchus"], inat: []},
  {asw: ["Pseudophilautus pardus"], inat: []},
  {asw: ["Pseudophilautus rugatus"], inat: []},
  {asw: ["Pseudophilautus stellatus"], inat: []},
  {asw: ["Pseudophilautus temporalis"], inat: []},
  {asw: ["Pseudophilautus variabilis"], inat: []},
  {asw: ["Pseudophilautus zal"], inat: []},
  {asw: ["Pseudophilautus zimmeri"], inat: []},
  {asw: ["Cynops wolterstorffi"], inat: []},
  #taxa: ["Hyla intermedia"], external_taxa: ["Hyla perrini","Hyla intermedia"] #https://www.frontiersin.org/files/Articles/407750/fevo-06-00144-HTML-r2/image_m/fevo-06-00144-g001.jpg
  #taxa: ["Scinax quinquefasciatus"], external_taxa: ["Scinax tsachila","Scinax quinquefasciatus"] #https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0203169
  #Stumpffia edmondsi
  
]

leftovers = discrepancies.map{|row| row[:asw]}.flatten.uniq - asw_data.map{ |row| row[:name] }
if leftovers.count > 0
  puts "These are no longer in ASW"
  leftovers.each do |name|
    puts "\t" + name
  end
end

added = (discrepancies.map{|row| row[:inat]}.flatten.uniq - discrepancies.map{|row| row[:asw]}.flatten.uniq) &  asw_data.map{ |row| row[:name] }
if added.count > 0
  puts "These have been added to the ASW"
  added.each do |name|
    puts "\t" + name
  end
end

leftovers = discrepancies.map{|row| row[:inat]}.flatten.uniq - inat_names.map{ |row| row[:name] }
if leftovers.count > 0
  puts "These are no longer in iNat"
  leftovers.each do |name|
    puts "\t" + name
  end
end

added = (discrepancies.map{|row| row[:asw]}.flatten.uniq - discrepancies.map{|row| row[:inat]}.flatten.uniq) &  inat_names.map{ |row| row[:name] }
if added.count > 0
  puts "These have been added to the ASW"
  added.each do |name|
    puts "\t" + name
  end
end

swaps = []
not_in_asw = ( inat_names.map{ |a| a[:name] } - asw_data.map{ |row| row[:name] } )
if not_in_asw.count > 0
  puts "These are species in the inat, not in asw..."
  not_in_asw.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:inat]}.flatten.include? name
      unless swaps.map{|a| a[:in]}.include? name
        puts "\t" + name
      end
    end
  end
end

swaps << {in: "Rana huanrensis", out: "Rana huanrenensis"}
swaps << {in: "Kurixalus ananjevae", out: "Gracixalus ananjevae"}
swaps << {in: "Chiromantis inexpectatus", out: "Feihyla inexpectata"}
swaps << {in: "Adelophryne mucronatus", out: "Adelophryne mucronata"}
swaps << {in: "Pristimantis reclusas", out: "Pristimantis reclusus"}
swaps << {in: "Colostethus fraterdanieli", out: "Leucostethus fraterdanieli"}
swaps << {in: "Ranoidea graminea", out: "Nyctimystes gramineus"}
swaps << {in: "Litoria hunti", out:  "Nyctimystes hunti"}
swaps << {in: "Ranoidea sauroni", out: "Nyctimystes sauroni"}
swaps << {in: "Nyctimystes dux", out: "Nyctimystes gramineus"}
swaps << {in: "Leptobrachium rakhinensis", out: "Leptobrachium rakhinense"}

  
news  = []
#build swaps from these to indicate how these taxa should be dealt with
# These are species in ASW, not in iNat
not_in_inat = ( asw_data.map{ |row| row[:name] } - inat_names.map{ |a| a[:name] } )
if not_in_inat.count > 0
  puts "These are species in ASW, not in the ref..."
  not_in_inat.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:asw]}.flatten.include? name
      #ignore taxa accounted for by the above swaps
      unless swaps.map{|a| a[:out]}.include? name
        puts "\t" + name
        news << name
      end
    end
  end
end

news = ["Lissotriton graecus", "Poyntonophrynus pachnodes", "Rheobatrachus silus", "Rheobatrachus vitellinus", "Taudactylus diurnus", "Dryophytes squirellus", "Leptobrachium rakhinense", "Trachycephalus vermiculatus", "Brachycephalus mirissimus", "Ischnocnema colibri", "Ischnocnema parnaso", "Adelophryne michelin", "Adelophryne mucronata", "Amazophrynella moisesii", "Amazophrynella teko", "Amazophrynella xinguensis", "Allobates tinae", "Boana caiapo", "Boana icamiaba", "Proceratophrys ararype", "Phrynomedusa fimbriata", "Ichthophis cardamomensis", "Hyliola regilla", "Dryophytes versicolor", "Dryophytes immaculatus", "Dryophytes japonicus", "Leptobrachella mangshanensis", "Leptobrachella wuhuangmontis", "Leptobrachella yunkaiensis", "Odorrana kweichowensis", "Rana huanrenensis", "Gracixalus tianlinensis", "Kurixalus yangi", "Cynops wolterstorffi", "Pristimantis reclusus", "Atelopus longirostris", "Leucostethus fraterdanieli", "Leucostethus jota", "Hyloxalus felixcoperari", "Hyloxalus sanctamariensis", "Scinax caprarius", "Incilius periglenes", "Smilisca manisorum", "Eleutherodactylus geitonos", "Pristimantis tiktik", "Amazophrynella siona", "Trachycephalus macrotis", "Trachycephalus quadrangulum", "Scinax tsachila", "Dryophytes bocourti", "Dryophytes walkeri", "Craugastor chrysozetetes", "Minervarya agricola", "Pseudophilautus nasutus", "Leptophryne javanica", "Leptobrachella bondangensis", "Leptobrachella fusca", "Nyctimystes hunti", "Hyla perrini", "Boophis masoala", "Guibemantis albomaculatus", "Guibemantis woosteri", "Mantidactylus schulzi", "Feihyla inexpectata", "Kurixalus chaseni", "Hyliola cadaverina", "Hyliola hypochondriaca", "Dryophytes arboricola", "Dryophytes arenicolor", "Dryophytes euphorbiaceus", "Dryophytes eximius", "Dryophytes plicatus", "Dryophytes wrightorum", "Leptobrachium tenasserimense", "Nyctimystes gramineus", "Nyctimystes nullicedens", "Nyctimystes pallidofemora", "Nyctimystes sauroni", "Phrynopus mariellaleo", "Dryophytes cinereus", "Hypogeophis montanus", "Nannophrys guentheri", "Lankanectes pera", "Pseudophilautus adspersus", "Pseudophilautus dimbullae", "Pseudophilautus eximius", "Pseudophilautus extirpo", "Pseudophilautus halyi", "Pseudophilautus hypomelas", "Pseudophilautus leucorhinus", "Pseudophilautus maia", "Pseudophilautus malcolmsmithi", "Pseudophilautus nanus", "Pseudophilautus oxyrhynchus", "Pseudophilautus pardus", "Pseudophilautus rugatus", "Pseudophilautus stellatus", "Pseudophilautus temporalis", "Pseudophilautus variabilis", "Pseudophilautus zal", "Pseudophilautus zimmeri", "Hyliola sierra", "Dryophytes andersonii", "Dryophytes avivoca", "Dryophytes chrysoscelis", "Dryophytes femoralis", "Dryophytes gratiosus", "Lithobates fisheri", "Eurycea braggi", "Eurycea hillisi", "Eurycea nerea", "Eurycea paludicola", "Eurycea sphagnicola", "Pseudotriton diastictus", "Aneides iecanus", "Aneides niger", "Desmognathus aureatus", "Desmognathus melanius", "Desmognathus valentinei", "Atelopus vogli", "Mannophryne molinai", "Micryletta nigromaculata", "Gracixalus ananjevae", "Ichthophis catlocensis", "Ichthophis chaloensis", "Ptychadena mutinondoensis"]
