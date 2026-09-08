class PagesController < ApplicationController
  skip_before_action :require_admin
  def index
    response.headers["Cache-Control"] = "no-store"
    response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob: data:; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
    send_file Rails.root.join("public/index.html"), type: "text/html", disposition: "inline"
  end

  def demo
    project = Project.find_by!(name: "Agendario · Demo")
    html = File.read(Rails.root.join("public/demo-template.html")).gsub("__PROJECT_KEY__", ERB::Util.html_escape(project.public_key))
    render html: html.html_safe
  end
end
