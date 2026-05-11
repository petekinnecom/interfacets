import React from 'react';

const Button = ({ label, onClick }) => {
  return (
    <button onClick={onClick} data-testid="test-button">
      {label}
    </button>
  );
};

export default Button;
