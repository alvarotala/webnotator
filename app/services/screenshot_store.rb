class ScreenshotStore
  MAX_SIZE = 5.megabytes
  class Invalid < StandardError; end

  def self.root
    Rails.root.join("storage", Rails.env)
  end

  def self.write(upload)
    raise Invalid, "Adjuntá un archivo de imagen" unless upload.is_a?(ActionDispatch::Http::UploadedFile)
    raise Invalid, "La imagen debe pesar como máximo 5 MB" if upload.size > MAX_SIZE
    bytes = upload.read
    type = if bytes.start_with?("\x89PNG\r\n\x1a\n".b)
      "image/png"
    elsif bytes.start_with?("\xff\xd8\xff".b)
      "image/jpeg"
    elsif bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP"
      "image/webp"
    end
    raise Invalid, "Adjuntá una imagen PNG, JPEG o WebP" unless type
    key = SecureRandom.hex(32)
    FileUtils.mkdir_p(root)
    File.binwrite(root.join(key), bytes)
    [key, type]
  end

  def self.delete(key)
    FileUtils.rm_f(root.join(key)) if key
  end
end
