require 'clubhouse2'
require 'YAML'

class Generator
  API_KEY = 'API_KEY'
  YEAR = '2019'
  PROACTIVE_LABEL_NAME = 'proactive'
  REACTIVE_LABEL_NAME = 'reactive'
  NON_PRODUCT_LABEL_NAME = 'Non-product'
  STORY_TYPE_BUG = 'bug'
  STORY_TYPE_CHORE = 'chore'
  IN_QA_NAME = 'In QA'
  COMPLETED_NAME = 'Completed'  


  def api_key
    config = YAML::load(File.open('config/application.yml'))

    config[API_KEY]
  end

  def point_string(story)
    if story.story_type == STORY_TYPE_BUG 
      return '-'
    else
      return story.estimate
    end
  end

  def story_stats(stories)
    num_stories = 0
    points = 0

    stories.each do |story|
      num_stories += 1
      points += (story.estimate || 0)
    end

    return num_stories, points
  end

  def issue_type(story)
    if story.story_type == STORY_TYPE_CHORE
      return "Chore"
    elsif story.story_type == STORY_TYPE_BUG
      return "Bug"
    else

      if story.labels.map(&:name).include? NON_PRODUCT_LABEL_NAME
        return "Non-product Story"
      elsif story.labels.map(&:name).include? REACTIVE_LABEL_NAME
        return "Reactive Story"
      else
        return "Proactive Story"
      end
    end
  end

  def generate_table_body(stories)
    result = ''

    stories.sort_by {|story| story.estimate || 0 }.reverse.each do |story|
      result += <<-HTML
        <tr>
          <td>CH-#{story.id}</td>
          <td>#{issue_type(story)}</td>
          <td>#{story.name}</td>
          <td>#{point_string(story)}</td>
        </tr>
      HTML
    end

    return result
  end

  def generate_table(stories)


    result = <<-HTML
      <table class="table table-striped table-bordered table-sm text-left issues">
        <thead>
          <tr> 
            <th width="10%">
              Issue<br/> 
              Number
            </th>
            <th width="15%">
              Issue<br/>
              Type
            </th>
            <th width="50%">
              Name
            </th>
            <th width="10%">
              Points
            </th>
          </tr>
        </thead>
        <tbody>
          #{generate_table_body(stories)}
        </tbody>
      </table>
    HTML
  end

  def generate_email(sprint_number)
    sprint_number = sprint_number.to_i
    client = Clubhouse::Client.new(api_key: api_key)
    sprint_label  = client.label(name: "Sprint #{YEAR}-#{sprint_number}")
    proactive_label = client.label(name: PROACTIVE_LABEL_NAME)
    reactive_label = client.label(name: REACTIVE_LABEL_NAME)
    non_product_label = client.label(name: NON_PRODUCT_LABEL_NAME)

    stories = client.stories(archived: false, labels: sprint_label)

    points_completed = sprint_label.stats["num_points_completed"]
    stories_completed = sprint_label.stats["num_stories_completed"]

    in_qa_state = client.workflow.state(name: IN_QA_NAME)
    completed_state = client.workflow.state(name: COMPLETED_NAME)
    in_progress_state_ids = client.workflow.states.reject { |state| state == in_qa_state || state == completed_state }.map(&:id)

    num_stories_completed = sprint_label.stats['num_stories_completed']
    points_completed = sprint_label.stats['num_points_completed']

    completed_stories = sprint_label.stories.select {|story| story.workflow_state_id == completed_state.id}
    in_qa_stories = sprint_label.stories.select {|story| story.workflow_state_id == in_qa_state.id}
    in_progress_stories = stories.select {|story| in_progress_state_ids.include?(story.workflow_state_id) }

    completed_non_product_stories = completed_stories.select {|story| story.labels.include?(non_product_label) && story.story_type != STORY_TYPE_BUG }
    completed_proactive_stories = completed_stories.select {|story| story.labels.include?(proactive_label) && story.story_type != STORY_TYPE_BUG }
    completed_reactive_stories = completed_stories.select {|story| story.labels.include?(reactive_label) && story.story_type != STORY_TYPE_BUG }
    completed_bugs = completed_stories.select {|story| story.story_type == STORY_TYPE_BUG }

    num_stories_nonproduct, points_nonproduct = story_stats(completed_non_product_stories)
    num_stories_reactive, points_reactive = story_stats(completed_reactive_stories)
    num_stories_proactive, points_proactive = story_stats(completed_proactive_stories)
    num_bugs, points_bugs = story_stats(completed_bugs)
    num_stories_qa, points_qa = story_stats(in_qa_stories)
    num_stories_in_progress, points_in_progress = story_stats(in_progress_stories)

    percent_reactive = points_reactive / points_completed.to_f * 100
    percent_proactive = points_proactive / points_completed.to_f * 100
    percent_nonproduct = points_nonproduct / points_completed.to_f * 100

    result = <<-HTML
    <html>
      <head>
        <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css" integrity="sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO" crossorigin="anonymous">
        <style type="text/css">
          table.issues{
            width: 60%;
          }
        </style>
      </head>
      <body>
        <p>This sprint our velocity was [up/down/the same]: #{points_completed} points ([up/down from X] last sprint).</p>

        <h5>Story breakdown stats:</h5>
        <p>
          <ul>
            <li><strong>Number Proactive Stories vs Reactive Stories vs Non-product vs Bugs:</strong> #{num_stories_proactive} vs #{num_stories_reactive} vs vs #{num_stories_nonproduct} vs #{num_bugs}</li>
            <li><strong>Proactive vs Reactive vs Non-Product Points:</strong> #{points_proactive} (#{"%.1f" % percent_proactive}%) vs #{points_reactive} (#{"%.1f" % percent_reactive}%) vs #{points_nonproduct} (#{"%.1f" % percent_nonproduct}%)</li>
          </ul>
        </p>

        <h5>Heroes:</h5>
        <p>
        </p>

        <h5>Hassles:</h5>
        <p>
        </p>

        <h5>Completed (#{points_completed}):</h5>
        #{generate_table(completed_stories)}

        <h5>In QA (#{points_qa}):</h5>
        #{generate_table(in_qa_stories)}    

        <h5>In Progress (#{points_in_progress}):</h5>
        #{generate_table(in_progress_stories)}
      </body>
    </html>

    HTML
  end
end

sprint = ARGV[0]
generator = Generator.new
path = "sprints/sprint-#{Generator::YEAR}-#{sprint}.html"
html = generator.generate_email(sprint)
File.open(path, 'w') { |file| file.write(html) }
system %{open "#{path}"}
puts "======================================================================================"
puts "=                      Done Generating HTML                                          ="
puts "======================================================================================"