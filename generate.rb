require 'clubhouse2'

class Generator
  API_KEY = '5bd63896-1d3b-4259-9e1c-545ac2283745'
  YEAR = '2018'

  def point_string(story)
    if story.story_type == "bug"
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
    if story.story_type == "bug"
      return "Bug"
    else
      if story.labels.map(&:name).include? "reactive"
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
      <table>
        <thead>
          <tr> 
            <th>
              Issue Number
            </th>
            <th>
              Issue Type
            </th>
            <th>
              Name
            </th>
            <th>
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
    client = Clubhouse::Client.new(api_key: API_KEY)
    sprint_label  = client.label(name: "Sprint #{YEAR}-#{sprint_number}")
    proactive_label = client.label(name: "proactive")
    reactive_label = client.label(name: "reactive")

    stories = client.stories(archived: false, labels: sprint_label)

    points_completed = sprint_label.stats["num_points_completed"]
    stories_completed = sprint_label.stats["num_stories_completed"]

    in_qa_state = client.workflow.state(name: 'In QA')
    completed_state = client.workflow.state(name: 'Completed')
    in_progress_state_ids = client.workflow.states.reject { |state| state == in_qa_state || state == completed_state }.map(&:id)

    num_stories_completed = sprint_label.stats['num_stories_completed']
    points_completed = sprint_label.stats['num_points_completed']

    completed_stories = sprint_label.stories.select {|story| story.workflow_state_id == completed_state.id}
    in_qa_stories = client.stories(archived: false, labels: [sprint_label], 
      workflow_state_id: in_qa_state.id)
    in_progress_stories = stories.select {|story| in_progress_state_ids.include?(story.workflow_state_id) }

    completed_proactive_stories = completed_stories.select {|story| story.labels.include?(proactive_label) && story.story_type != "bug" }
    completed_reactive_stories = completed_stories.select {|story| story.labels.include?(reactive_label) && story.story_type != "bug" }
    completed_bugs = completed_stories.select {|story| story.story_type == "bug" }

    num_stories_reactive, points_reactive = story_stats(completed_reactive_stories)
    num_stories_proactive, points_proactive = story_stats(completed_proactive_stories)
    num_bugs, points_bugs = story_stats(completed_bugs)
    num_stories_qa, points_qa = story_stats(in_qa_stories)
    num_stories_in_progress, points_in_progress = story_stats(in_progress_stories)

    percent_reactive = points_reactive / points_completed.to_f * 100
    percent_proactive = points_proactive / points_completed.to_f * 100

    result = <<-HTML
    <p>This sprint our velocity was [up/down/the same]: #{points_completed} points ([up/down from X] last sprint).</p>

    <p>
      <strong>Story breakdown stats:</strong>
      <ul>
        <li><strong>Number Proactive Stories vs Reactive Stories vs Bugs:</strong> #{num_stories_proactive} vs #{num_stories_reactive} vs #{num_bugs}</li>
        <li><strong>Points Proactive vs Reactive:</strong> #{points_proactive} (#{"%.1f" % percent_proactive}%) vs #{points_reactive} (#{"%.1f" % percent_reactive}%)</li>
      </ul>
    </p>

    <p>
      <strong>Heroes:</strong>
    </p>

    <p>
      <strong>Heroes:</strong>
    </p>

    <p><strong>Completed (#{points_completed}):</strong></p>
    #{generate_table(completed_stories)}

    <p><strong>In QA (#{points_qa}):</strong></p>
    #{generate_table(in_qa_stories)}    

    <p><strong>In Progress (#{points_in_progress}):</strong></p>
    #{generate_table(in_progress_stories)}

    HTML
  end
end

sprint = ARGV[0]
generator = Generator.new
path = "sprints/sprint-#{Generator::YEAR}-#{sprint}.html"
html = generator.generate_email(sprint)
File.open(path, 'w') { |file| file.write(html) }
puts "======================================================================================"
puts "=                      Done Generating HTML                                          ="
puts "======================================================================================"