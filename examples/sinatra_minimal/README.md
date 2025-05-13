# Sinatra + Interfacets

A minimal Sinatra app with Interfacets-powered UI.

## Setup

1. Install Ruby dependencies:
   ```bash
   bundle install
   ```

2. Install JavaScript dependencies:
   ```bash
   npm install
   ```

3. Build JavaScript assets:
   ```bash
   npm run build
   ```

## Running

In one terminal, start the asset watcher:
```bash
npm run watch
```

In another terminal, start the Sinatra server:
```bash
bundle exec rackup -p 4567
```

Then visit: http://localhost:4567

## Structure

- `app.rb` - Main Sinatra application
- `app/facets/hello_facet.rb` - Interfacets facet definition
- `app/javascript/` - JavaScript entry points
- `views/index.erb` - HTML template
- `public/assets/` - Built JavaScript assets
