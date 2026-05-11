import React from 'react';

export function withTransform(Component, transforms) {
  const WrappedComponent = React.forwardRef((props, ref) => {
    const transformedProps = { ...props, ref };

    if (transforms) {
      Object.keys(transforms).forEach(eventName => {
        let originalHandler = props[eventName];
        
        if (typeof originalHandler === 'function') {
          const transform = transforms[eventName];
          
          if (transform && typeof transform === 'object' && !Array.isArray(transform)) {
            transformedProps[eventName] = (...args) => {
              const payload = {};
              Object.keys(transform).forEach(key => {
                const path = transform[key];
                let value = args;
                if (Array.isArray(path)) {
                  for (const part of path) {
                    if (value == null) {
                      value = null;
                      break;
                    }
                    value = value[part];
                  }
                } else {
                  value = null;
                }
                
                payload[key] = value !== undefined ? value : null;
              });
              originalHandler(payload);
            };
          } else {
            // Transform is explicitly null, a string (like "debounce"), or missing/invalid.
            // Requirement: pass null as the payload, do not pass original arguments.
            transformedProps[eventName] = () => originalHandler(null);
          }
        }
      });
    }

    return React.createElement(Component, transformedProps);
  });

  WrappedComponent.displayName = `withTransform(${Component.displayName || Component.name || 'Component'})`;
  return WrappedComponent;
}
