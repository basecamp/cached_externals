module CachedExternals
  def self.recipe_path
    File.expand_path('../../recipes', __FILE__)
  end
end
