namespace :sc_archives do

  task load: :environment do |t, args|

    sc_log = Logger.new('log/sc_requests_import.log')

    files = Dir.glob('tmp/sc_archives_repaired/*.csv')

    files.each do |f|
      begin
        sc_log.info "Loading file: #{f}"
        CSV.foreach f, headers: true do |row|
          begin
            sc_params = convert_csv(row.to_hash)
            scr = SpecialCollectionsRequest.where(id: sc_params['id']).first
            if scr.present?
              # sc exists, update?
              sc_log.info "Record #{sc_params['id']} Exists"
            else
              # create
              scr = SpecialCollectionsRequest.new(sc_params)
              if scr.user_id.blank?
                scr.user_id = 'BLANK'
              end
              if !scr.valid?
                sc_log.error scr.errors
              end
              r_id = sc_params['id'].to_i
              if r_id != 0
#                autoincrement = "ALTER TABLE special_collections_requests AUTO_INCREMENT=#{ActiveRecord::Base.sanitize(r_id)};"
#                ActiveRecord::Base.connection.execute(autoincrement)
                scr.id = r_id
                scr.save!
                sc_log.info "Saved #{scr.id} from row #{r_id} "
              end
            end
          rescue Exception => e
            sc_log.error "Bad Row from file '#{f}: #{row.to_s}"
          end
        end
      rescue Exception => e
        sc_log.error "File #{f}" + e.to_s
      end
    end
  end

  task verify_files: :environment do |t, args|
    files = Dir.glob('tmp/sc_archives_repaired/*.csv')

    count = 0
    files.each do |f|
      begin
        CSV.read f
      rescue Exception => e
        pp "(#{ count += 1 }) Error with #{f}: #{e.to_s}"
      end
    end
    nil

  end


  def convert_csv(row)
    row.delete nil

    # key request_ID wont match the string "request_ID"
    row['id'] = row.delete row.first.first

    row['created_at'] = validated_date row['created_at']
    row['processed_at'] = validated_date row['processed_at']

    row
  end

  def validated_date(d)
    valid_date = nil
    unless valid_date = DateTime.parse(d) rescue false
      begin
        valid_date = DateTime.strptime(d, '%m/%d/%y %k:%M')
      rescue
        valid_date = nil
      end
    end
    if valid_date
      valid_date.in_time_zone
    else
      nil
    end
  end
end
