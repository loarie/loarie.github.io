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

#These are species in Amphibians Species of the World that are known to be extinct and are thus ignored...
known_extinct = ["Adenomus kandianus", "Atelopus ignescens", "Atelopus longirostris", "Atelopus vogli", "Incilius periglenes", "Craugastor chrysozetetes", "Nannophrys guentheri", "Rheobatrachus silus", "Rheobatrachus vitellinus", "Taudactylus diurnus", "Phrynomedusa fimbriata", "Lithobates fisheri", "Pseudophilautus adspersus", "Pseudophilautus dimbullae", "Pseudophilautus eximius", "Pseudophilautus extirpo", "Pseudophilautus halyi", "Pseudophilautus hypomelas", "Pseudophilautus leucorhinus", "Pseudophilautus maia", "Pseudophilautus malcolmsmithi", "Pseudophilautus nanus", "Pseudophilautus nasutus", "Pseudophilautus oxyrhynchus", "Pseudophilautus pardus", "Pseudophilautus rugatus", "Pseudophilautus stellatus", "Pseudophilautus temporalis", "Pseudophilautus variabilis", "Pseudophilautus zal", "Pseudophilautus zimmeri", "Plethodon ainsworthi", "Cynops wolterstorffi"]
#The approach here is to scrape ASW by looping through countries - not idea, but easier/faster than traversing the taxonomy
puts "Scraping ASW..."
key = {614=>"Afganistan",389=>"Albania",445=>"Algeria",388=>"Andorra",302=>"Angola",153=>"Anguilla",182=>"Antigua and Barbuda",414=>"Argentina",305=>"Armenia",541=>"Aruba",555=>"Australia",584=>"Austria",219=>"Azerbaijan",527=>"Bahamas",374=>"Bahrain",191=>"Bangladesh",457=>"Barbados",232=>"Belarus",477=>"Belgium",440=>"Belize",273=>"Benin",569=>"Bermuda",593=>"Bhutan",333=>"Bolivia",294=>"Bonaire",607=>"Bosnia and Herzegovina",442=>"Botswana",194=>"Brazil",347=>"Brunei",450=>"Bulgaria",478=>"Burkina Faso",373=>"Burundi",269=>"Cambodia",471=>"Cameroon",563=>"Canada",588=>"Cape Verde",188=>"Cayman Islands",521=>"Central African Republic",583=>"Chad",253=>"Chile",505=>"China, People's Republic of",599=>"Colombia",266=>"Comoros",160=>"Congo, Democratic Republic of the",606=>"Congo, Republic of the",260=>"Costa Rica",436=>"Croatia",330=>"Cuba",303=>"Curaçao",564=>"Cyprus",520=>"Czech Republic",386=>"Denmark",321=>"Djibouti",204=>"Dominica",419=>"Dominican Republic",367=>"East Timor",200=>"Ecuador",554=>"Egypt",534=>"El Salvador",162=>"Equatorial Guinea",301=>"Eritrea",508=>"Estonia",163=>"Ethiopia",585=>"Fiji",581=>"Finland",262=>"France",482=>"French Guiana",551=>"Gabon",601=>"Gambia",611=>"Georgia",472=>"Germany",316=>"Ghana",243=>"Greece",245=>"Grenada",514=>"Guadeloupe",490=>"Guam",509=>"Guatemala",155=>"Guinea",307=>"Guinea-Bissau",161=>"Guyana",486=>"Haiti",310=>"Honduras",278=>"Hungary",387=>"Iles des Saintes",441=>"India",166=>"Indonesia",349=>"Iran",223=>"Iraq",513=>"Ireland",206=>"Israel",365=>"Italy",544=>"Ivory Coast",203=>"Jamaica",196=>"Japan",590=>"Jordan",362=>"Kazakhstan",552=>"Kenya",494=>"Korea, Democratic People's Republic (North)",537=>"Korea, Republic of (South)",573=>"Kyrgyzstan",435=>"La Desirade",451=>"Laos",181=>"Latvia",454=>"Lebanon",589=>"Lesotho",600=>"Liberia",491=>"Libya",498=>"Liechtenstein",561=>"Lithuania",344=>"Luxembourg",556=>"Macedonia",208=>"Madagascar",187=>"Malawi",267=>"Malaysia",190=>"Maldives",202=>"Mali",210=>"Malta",352=>"Martinique",574=>"Mauritania",205788=>"Mauritius",251=>"Mayotte",525=>"Mexico",549=>"Moldova",480=>"Monaco",277=>"Mongolia",343=>"Montenegro",341=>"Montserrat",424=>"Morocco",400=>"Mozambique",375=>"Myanmar",444=>"Namibia",392=>"Nepal",193=>"Netherlands",613=>"New Caledonia",370=>"New Zealand",312=>"Nicaragua",235=>"Niger",174=>"Nigeria",562=>"Norway",511=>"Oman",283=>"Pakistan",582=>"Palau",492=>"Panama",568=>"Papua New Guinea",432=>"Paraguay",167=>"Peru",591=>"Philippines",540=>"Poland",175=>"Portugal",497=>"Puerto Rico",378=>"Reunion",241=>"Romania",578=>"Russia",272=>"Rwanda",288=>"Saba",533=>"Saint Helena",239=>"Saint Kitts and Nevis",280=>"Saint Lucia",518=>"Saint Vincent and the Grenadines",270=>"Samoa",248=>"San Marino",597=>"Sao Tome and Principe",306=>"Saudi Arabia",617=>"Senegal",185=>"Serbia",577=>"Seychelles",506=>"Sierra Leone",461=>"Singapore",323=>"Slovakia",438=>"Slovenia",244123=>"Solomon Islands",393=>"Somalia",337=>"South Africa",231=>"South Moluccas",363=>"South Sudan",332=>"Spain",502=>"Sri Lanka",615=>"Sudan",173=>"Surinam",437=>"Swaziland",150=>"Sweden",335=>"Switzerland",495=>"Syria",448=>"Taiwan",325=>"Tajikistan",358=>"Tanzania",456=>"Thailand",545=>"Togo",281=>"Trinidad and Tobago",425=>"Tunisia",183=>"Turkey",309=>"Turkmenistan",324=>"Turks and Caicos Islands",592=>"Uganda",238=>"Ukraine",460=>"United Arab Emirates",559=>"United Kingdom",603=>"United States of America",274=>"Uruguay",484=>"Uzbekistan",515=>"Vanuatu",609=>"Venezuela",236=>"Vietnam",384=>"Virgin Islands, British",322=>"Virgin Islands, U.S.",300=>"Western Sahara",371=>"Yemen",499=>"Zambia",366=>"Zimbabwe"}
rev_key = key.invert
asw_data = []
key.each do |code,country|
  file="http://research.amnh.org/vz/herpetology/amphibia/content/search?country=#{code}"
  page = Nokogiri::HTML(open(file))   
  records = page.css('div.Species a')
  records.each do |record|
    name = record.text.gsub("\n","").strip.sub(/\([^\)]*\)/, '').split[0..1].join(" ").gsub("\"","")
    already_included = asw_data.map{|a| a[:name] == name}
    if already_included.any?
      index = already_included.index(true)
      asw_data[index][:countries] << code
    else
      unless known_extinct.include? name
        asw_data << {name: name, countries: [code]}
      end
    end
  end
end

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
  {asw: ["Ichthophis cardamomensis"], inat: ["Ichthyophis cardamomensis"]},
  {asw: ["Ichthophis catlocensis"], inat: ["Ichthyophis catlocensis"]},
  {asw: ["Ichthophis chaloensis"], inat: ["Ichthyophis chaloensis"]},
  {asw: ["Microhyla mihintaleiWijayathilaka,"], inat: ["Microhyla mihintalei"]},
  {asw: ["Chlacorana crassiovis"], inat: ["Chalcorana crassiovis"]},
  {asw: [], inat: ["Dendropsophus nekronastes"]},
  {asw: [], inat: ["Hylodes caete"]},
  {asw: [], inat: ["Megophrys koui"]},  
  {asw: ["Aneides iecanus","Aneides niger","Aneides flavipunctatus"], inat: ["Aneides flavipunctatus"]},
  {asw: ["Desmognathus aureatus","Desmognathus melanius","Desmognathus marmoratus"], inat: ["Desmognathus marmoratus"]},
  {asw: ["Desmognathus auriculatus","Desmognathus valentinei"], inat: ["Desmognathus auriculatus"]},
  {asw: ["Pseudotriton diastictus","Pseudotriton montanus"], inat: ["Pseudotriton montanus"]},
  {asw: ["Trachycephalus typhonius","Trachycephalus macrotis","Trachycephalus quadrangulum","Trachycephalus vermiculatus"], inat: ["Trachycephalus typhonius"]},
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
  {asw: ["Eurycea quadridigitata","Eurycea hillisi","Eurycea paludicola","Eurycea sphagnicola"], inat: ["Eurycea quadridigitata"]},
  {asw: ["Eurycea spelaea", "Eurycea nerea", "Eurycea braggi"], inat: ["Eurycea spelaea"]},  
  {asw: ["Bombina variagata"], inat: ["Bombina pachypus","Bombina variagata"]},
  {asw: ["Lissotriton graecus","Lissotriton vulgaris","Lissotriton meridionalis"], inat: ["Lissotriton vulgaris"]},
  {asw: ["Smilisca manisorum","Smilisca baudin"], inat: ["Smilisca baudin"]},
  {asw: ["Megophrus koui"], inat: ["Megophrys koui"]}
]

# These are species in iNat, not in ASW
not_in_asw = ( inat_names.map{ |a| a[:name] } - asw_data.map{ |row| row[:name] } )
if not_in_asw.count > 0
  puts "These are species in the iNat, not in ASW..."
  not_in_asw.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:ref]}.flatten.include? name
      puts "\t" + name
    end
  end
end
#build swaps from these to indicate how these taxa should be dealt with
swaps = Hash.new

# These are species in ASW, not in iNat
not_in_inat = ( asw_data.map{ |row| row[:name] } - inat_names.map{ |a| a[:name] } )
if not_in_inat.count > 0
  puts "These are species in ASW, not in iNat..."
  not_in_inat.each do |name|
    #ignore discrepancies
    unless discrepancies.map{|row| row[:asw]}.flatten.include? name
      #ignore taxa accounted for by the above swaps
      unless swaps.values.include? name
        puts "\t" + name
      end
    end
  end
end

