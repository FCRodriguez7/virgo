class MergeSpecialCollectionsUsers < ActiveRecord::Migration
  def up
    add_column :special_collections_users, :is_admin, :boolean, default: true

    SpecialCollectionsRequestsInternalUser.all.each do |scriu|

      sc_user = SpecialCollectionsUser.find_by_computing_id(scriu.computing_id)

      if sc_user.present?
        # do nothing
      else
        SpecialCollectionsUser.create(computing_id: scriu.computing_id, is_admin: false)
        p "created non-admin SC user: #{scriu.computing_id}"
      end
    end

    drop_table :special_collections_requests_internal_users
  end

  def down
    # there's no going back
  end
end
