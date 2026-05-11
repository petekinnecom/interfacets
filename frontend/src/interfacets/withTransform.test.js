import { describe, it, expect, vi } from 'vitest';
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { withTransform } from './withTransform.js';

// Simple mock for a component
const MockComponent = React.forwardRef((props, ref) => {
  return React.createElement('button', { 
    ...props, 
    ref,
    'data-testid': 'mock-button'
  }, props.children || 'Click Me');
});
MockComponent.displayName = 'MockComponent';

describe('withTransform', () => {
  it('wraps component display name', () => {
    const Wrapped = withTransform(MockComponent, {});
    expect(Wrapped.displayName).toBe('withTransform(MockComponent)');
  });

  it('passes through props and children', () => {
    const Wrapped = withTransform(MockComponent, {});
    render(React.createElement(Wrapped, { title: 'hello' }, 'Child Content'));
    
    const button = screen.getByTestId('mock-button');
    expect(button.getAttribute('title')).toBe('hello');
    expect(button.textContent).toBe('Child Content');
  });

  it('transforms event payload with valid object transform', () => {
    const transforms = {
      onCustom: {
        value: [0, 'target', 'value'],
        custom: [0, 'customField']
      }
    };
    let capturedProps;
    const Inspector = (props) => {
      capturedProps = props;
      return null;
    };
    const WrappedInspector = withTransform(Inspector, transforms);
    const handler = vi.fn();
    render(React.createElement(WrappedInspector, { onCustom: handler }));
    
    // Simulate call with a custom object that mimics an event
    capturedProps.onCustom({ 
      target: { value: 'target-value' },
      customField: 'custom-value'
    });
    
    expect(handler).toHaveBeenCalledWith({
      value: 'target-value',
      custom: 'custom-value'
    });
  });

  it('passes null when transform is explicitly null', () => {
    const transforms = {
      onClick: null
    };
    const Wrapped = withTransform(MockComponent, transforms);
    const handler = vi.fn();
    render(React.createElement(Wrapped, { onClick: handler }));
    
    const button = screen.getByTestId('mock-button');
    fireEvent.click(button);
    
    expect(handler).toHaveBeenCalledWith(null);
  });

  it('passes null when transform is a string', () => {
    const transforms = {
      onClick: 'debounce'
    };
    const Wrapped = withTransform(MockComponent, transforms);
    const handler = vi.fn();
    render(React.createElement(Wrapped, { onClick: handler }));
    
    const button = screen.getByTestId('mock-button');
    fireEvent.click(button);
    
    expect(handler).toHaveBeenCalledWith(null);
  });

  it('handles deep paths and missing values in paths', () => {
    const transforms = {
      onCustom: {
        nested: [0, 'data', 'deep', 'value'],
        missing: [0, 'data', 'missing']
      }
    };
    const Wrapped = withTransform(MockComponent, transforms);
    const handler = vi.fn();
    
    // We need to trigger the prop manually since fireEvent doesn't know about 'onCustom' 
    // in a way that maps to standard DOM events easily for a generic MockComponent.
    // But we can just render and then find the component props if we were using a more 
    // complex setup, OR just call the prop that was passed to MockComponent.
    
    let capturedProps;
    const Inspector = (props) => {
      capturedProps = props;
      return null;
    };
    const WrappedInspector = withTransform(Inspector, transforms);
    render(React.createElement(WrappedInspector, { onCustom: handler }));
    
    capturedProps.onCustom({
      data: { deep: { value: 42 } }
    });
    
    expect(handler).toHaveBeenCalledWith({
      nested: 42,
      missing: null
    });
  });
});
