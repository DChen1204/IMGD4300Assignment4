@group(0) @binding(0) var<uniform> res:   vec2f;
@group(0) @binding(1) var<storage> state: array<f32>;

// Helper function to convert 2D coordinates to 1D index
fn index( x:i32, y:i32 ) -> u32 {
  let _res = vec2i(res);
  let wrappedX = x % _res.x;
  let wrappedY = y % _res.y;

  // Handle negative wrapping
  let finalX = select( wrappedX + _res.x, wrappedX, wrappedX >= 0 );
  let finalY = select( wrappedY + _res.y, wrappedY, wrappedY >= 0 );

  // Multiply by 2 because each cell has 2 values (a and b)
  return u32( (finalY * _res.x + finalX ) * 2 );
}

@fragment 
fn fs( @builtin(position) pos : vec4f ) -> @location(0) vec4f {
  
  // Get pixel coordinates and array index for this pixel 
  let x = i32(pos.x);
  let y = i32(pos.y);
  let i = index(x, y);

  // Get chemical A and B values for the current pixel
  let A = state[i];
  let B = state[i + 1]; 

  // Draw A - B
  let diff = A - B;
  return vec4f(diff, diff, diff, 1.0);

}
