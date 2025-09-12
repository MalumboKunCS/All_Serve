class CloudinaryConfig {
  // Replace with your actual Cloudinary credentials
  static const String cloudName = 'dictaejrx';
  static const String apiKey = '381628448216952';
  static const String apiSecret = 'fD3DZQKI0lvlNtDffgr7t_tnwpA';
  
  // Cloudinary URL for direct uploads
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  
  // Base URL for image delivery
  static const String baseUrl = 'https://res.cloudinary.com/$cloudName/image/upload';
  
  // Upload presets for different use cases
  static const String profileImagePreset = 'all_serve_profile_images';
  static const String providerLogoPreset = 'all_serve_provider_logos';
  static const String providerGalleryPreset = 'all_serve_provider_gallery';
  static const String documentPreset = 'all_serve_documents';
  static const String categoryIconPreset = 'all_serve_category_icons';
}
