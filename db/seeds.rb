email = ENV.fetch("ADMIN_EMAIL").strip.downcase
unless Admin.exists?(email: email)
  Admin.create!(email: email, password: ENV.fetch("ADMIN_PASSWORD"))
  puts "Administrador creado: #{email}"
end
if ENV["SEED_DEMO"] == "true"
  origin = ENV.fetch("APP_URL")
  demo = Project.find_or_create_by!(name: "Agendario · Demo") { |p| p.origins = [origin] }
  if demo.annotations.empty?
    [
      ["change", "El título podría decir ‘Tu próxima pausa empieza acá’.", "María", "h1", "Reservá un momento para vos", "pending"],
      ["bug", "Al cambiar de servicio se mantiene el horario anterior. Debería volver a pedirme un horario disponible.", "Diego", "#service", "Servicio", "in_progress"],
      ["suggestion", "Me gustaría poder buscar el servicio escribiendo su nombre.", "María", "#service", "Servicio", "pending"]
    ].each do |kind, body, author, selector, text, status|
      demo.annotations.create!(kind: kind, body: body, author_name: author, page_url: "#{origin}/demo", page_title: "Agendario · Reserva", element: {selector: selector, tag: selector == "h1" ? "h1" : "select", text: text}, viewport: {width: 1440, height: 900}, status: status, client_id: SecureRandom.uuid)
    end
  end
end
