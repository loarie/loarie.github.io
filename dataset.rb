## Get set of obs ids of all verifiable observations in a taxon
taxon_id = 84718 #64784
obs = Observation.select("observations.id, observations.created_at").joins(:taxon).where("(taxon_id = ? OR taxa.ancestry LIKE (?) OR taxa.ancestry LIKE (?)) AND quality_grade IN (?)", taxon_id, "%/#{taxon_id}", "%/#{taxon_id}/%", ["needs_id","research"])
ids = obs.pluck(:id); nil

## dataset

# Get all current identifications of active, rank_level 10 taxa from the set of obs ids
sql_query = <<-SQL
 SELECT i.id, i.taxon_id, i.user_id, i.observation_id, i.created_at, i.taxon_change_id, i.category
 FROM identifications i, taxa t
 WHERE i.taxon_id = t.id AND i.observation_id IN (#{ids.join(",")})
 AND i.current = TRUE AND t.rank_level = 10 AND t.is_active = TRUE;
SQL
data = ActiveRecord::Base.connection.execute(sql_query)

# Keep only identifications where >2 per obs
id_freq = data.map{|row| row["observation_id"]}.inject(Hash.new(0)) {|hash,word| hash[word] += 1; hash }
keepers = id_freq.select{|k,v| v>1}.keys
data = data.select{|row| keepers.include? row["observation_id"]}

# Get the taxa from these identifications 
taxon_frequency_hash = data.map{|row| row["taxon_id"].to_i}.inject(Hash.new(0)) {|hash,word| hash[word] += 1; hash }
taxon_ids = taxon_frequency_hash.keys
inat_taxon_id_to_class_label = Hash[taxon_ids.map.with_index.to_a]; nil 
denom = taxon_frequency_hash.values.inject(0){|sum,x| sum + x }
global_class_priors = taxon_frequency_hash.values.collect { |n| n / denom.to_f }
dataset = {
  inat_taxon_id_to_class_label: inat_taxon_id_to_class_label,
  num_classes: taxon_ids.count,
  global_class_priors: global_class_priors
}; nil

## annos

# Store the identifications themselves
annos = data.map{|row|
  {
    anno: {
      gtype: "multiclass",
      label: inat_taxon_id_to_class_label[row["taxon_id"].to_i]
    },
    image_id: row["observation_id"],
    created_at: row["created_at"],
    worker_id: row["user_id"],
    id: row["id"]
  }
}; nil

## workers

# Store the identifiers themselves
user_ids = data.map{|a| a["user_id"]}.uniq; nil
users = user_ids.map{|i| {"id".to_sym => i}}; nil
workers = Hash[users.map{|row| row[:id]}.zip(users)]

## images

# We're not actually using images yet, so fake image urls since getting them is slow
=begin
sql_query = <<-SQL
 SELECT observation_id, photos.medium_url as url FROM observation_photos, photos
 WHERE photos.id = observation_photos.photo_id AND observation_id IN (#{ids.join(",")});
SQL
data4 = ActiveRecord::Base.connection.execute(sql_query)
=end
images = {} 
obs.each do |row|
  #matches = data4.select{|row2| row2["observation_id"].to_i == row[:id]}
  images[row[:id]] = {
      url: "https://static.inaturalist.org/photos/6547860/medium.jpg?1489358304", #matches[0]["url"],
      created_at: row[:created_at],
      id: row[:id],
      urls: ["https://static.inaturalist.org/photos/6547860/medium.jpg?1489358304"] #matches.map{|row2| row2["url"]}
    }
end

## taxonomy_data

# Will use this to get the taxonomy_data
=begin
sql_query = <<-SQL
 SELECT id, rank, rank_level, ancestry, is_active, iconic_taxon_id FROM taxa
 WHERE id IN (#{taxon_ids.join(",")});
SQL
data2 = ActiveRecord::Base.connection.execute(sql_query)
File.open("taxa.json","w") do |f|
  f.write(data2.map{|a| a}.to_json)
end
=end

# Write dataset to file
ob_label_pred_dataset = {images: images, workers: workers, annos: annos, dataset: dataset}; nil
File.open("ob_label_pred_dataset.json","w") do |f|
  f.write(ob_label_pred_dataset.to_json)
end


