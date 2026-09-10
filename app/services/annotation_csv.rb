class AnnotationCsv
  KINDS = { "bug" => "Error", "change" => "Cambio", "suggestion" => "Sugerencia" }.freeze
  STATUSES = { "pending" => "Pendiente", "in_progress" => "En curso", "resolved" => "Resuelto", "discarded" => "Ignorada" }.freeze

  def self.generate(project, base_url:, annotations: project.annotations.where.not(status: "discarded"))
    # UTF-8 BOM lets spreadsheet applications recognize accents correctly.
    output = +"\uFEFF"
    output << row(["ID", "Proyecto", "Autor", "Tipo", "Estado", "Anotación", "URL", "Título de página",
      "Selector", "Etiqueta", "Texto del elemento", "Ancho de pantalla", "Alto de pantalla", "Creada (UTC)", "Actualizada (UTC)", "Captura"])
    annotations.find_each(order: :desc) do |note|
      screenshot = note.screenshot_key.present? ? "#{base_url.delete_suffix('/')}/api/projects/#{project.id}/annotations/#{note.id}/screenshot" : nil
      output << row([note.id, project.name, note.author_name, KINDS.fetch(note.kind), STATUSES.fetch(note.status),
        note.body, note.page_url, note.page_title, note.element["selector"], note.element["tag"], note.element["text"],
        note.viewport["width"], note.viewport["height"], note.created_at.utc.iso8601, note.updated_at.utc.iso8601, screenshot])
    end
    output
  end

  def self.row(values)
    values.map do |value|
      text = value.to_s
      # Treat user text as data, including strings that spreadsheets could execute as formulas.
      text = "'#{text}" if text.match?(/\A(?:[[:space:]]*[=+@-]|[\t\r\n])/)
      '"' + text.gsub('"', '""') + '"'
    end.join(",") + "\r\n"
  end
  private_class_method :row
end
