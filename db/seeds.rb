
class TaxonWorks::SeedError < StandardError; end;

case Rails.env

when 'development'
  begin
    ApplicationRecord.transaction do
      a, u, p = nil, nil, nil 
      if User.where(is_administrator: true).any?
        raise TaxonWorks::SeedError, Rainbow('An administrator exists.').red
      else 
        a = User.create!(:administrator, email: 'admin@example.com', password: 'taxonworks', password_confirmation: 'taxonworks', is_administrator: true, self_created: true)
      end

      if User.where.not(is_administrator: true).any?
        raise TaxonWorks::SeedError, Rainbow('A user exists.').red
      else
        u = User.create!(email: 'user@example.com', password: 'taxonworks', password_confirmation: 'taxonworks', self_created: true)
      end
    end

    p = Project.create!(name: 'Default', by: a)
    ProjectMember.create!(project: p, user: u, by: u)

    puts Rainbow("Created an administrator #{a.email}, user #{u.email}, and project #{p.name} with them in it.").blue
  rescue ActiveRecord::RecordInvalid => e
    puts Rainbow("Failed with #{e.error.full_messages.join(', ')}.").red
  rescue TaxonWorks::SeedError => e
    puts e.message
  rescue
    raise
  end

when 'production'
  # Never ever do anything.  Production should be seeded with a Rake task or deploy script if need be.
when 'test'

end
