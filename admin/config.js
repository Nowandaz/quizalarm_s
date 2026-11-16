// Connection details for the admin website.
//
// Both values are PUBLIC by design: the publishable key only lets a browser
// talk to the project, and the database rules decide what each signed-in
// person may do. Never put a secret key in this file.
window.BRAINWAKE_CONFIG = {
  appName: 'BrainWake',   // working name; change it here to rename the site
  supabaseUrl: 'https://zsplxgvizlndnofsokxw.supabase.co',
  supabaseKey: 'sb_publishable_bE2OwJPR9O9mhzRi-HVPLw_lh7G7-LB',
  imageBucket: 'question-images',
};
