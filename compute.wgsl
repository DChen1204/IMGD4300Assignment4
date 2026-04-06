
// compute.wgsl - Compute shader for reaction-diffusion simulation
// It computes how the chemical concentrations of A and B in every pixel evolve based on diffusion and reaction equations.

// Uniforms
@group(0) @binding(0) var<uniform> res: vec2f;
@group(0) @binding(1) var<uniform> feed: f32;
@group(0) @binding(2) var<uniform> kill: f32;
@group(0) @binding(3) var<uniform> Da: f32;
@group(0) @binding(4) var<uniform> Db: f32;

// Storage buffers
@group(0) @binding(5) var<storage> statein: array<f32>;
@group(0) @binding(6) var<storage, read_write> stateout: array<f32>;

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

// Laplacians for diffusion
// Compute the Laplacian for chemical A at cell (x, y)
fn laplacianA( x:i32, y:i32) -> f32 {

  // Weighted sum of neighbor values for chemical A
  // Center cell has a weight of -1
  // Direct neighbors (up, down, left, right) have a weight of 0.2
  // Diagonal neighbors have a weight of 0.05

  let center = statein[ index(x, y) ]; // A value at (x, y)

  let sum = 
    statein[ index(x + 1, y) ] * 0.2 + // right
    statein[ index(x - 1, y) ] * 0.2 + // left
    statein[ index(x, y + 1) ] * 0.2 + // down
    statein[ index(x, y - 1) ] * 0.2 + // up
    statein[ index(x + 1, y + 1) ] * 0.05 + // down-right
    statein[ index(x - 1, y + 1) ] * 0.05 + // down-left
    statein[ index(x - 1, y - 1) ] * 0.05 + // up-left
    statein[ index(x + 1, y - 1) ] * 0.05; // up-right

   return sum - center; // Laplacian is the weighted sum minus the center value 

}

// Compute the Laplacian for chemical B at cell (x, y)
fn laplacianB( x:i32, y:i32) -> f32 {

  // Similar to laplacianA but for chemical B
  let center = statein[ index(x, y) + 1 ]; // B value at (x, y)

  let sum = 
    statein[ index(x + 1, y) + 1 ] * 0.2 + // right
    statein[ index(x - 1, y) + 1 ] * 0.2 + // left
    statein[ index(x, y + 1) + 1 ] * 0.2 + // down
    statein[ index(x, y - 1) + 1 ] * 0.2 + // up
    statein[ index(x + 1, y + 1) + 1 ] * 0.05 + // down-right
    statein[ index(x - 1, y + 1) + 1 ] * 0.05 + // down-left
    statein[ index(x - 1, y - 1) + 1 ] * 0.05 + // up-left
    statein[ index(x + 1, y - 1) + 1 ] * 0.05; // up-right

   return sum - center; 

}

// Style Map 
// Adds horizontal and vertical variatinons to feed and kill
fn getStyleParams( x:i32, y:i32, baseFeed: f32, baseKill: f32) -> vec2f {
  
  // Normalize coordinates to range [-0.5, 0.5]
  let nx = f32(x) / res.x - 0.5;
  let ny = f32(y) / res.y - 0.5;
  
  // Add variations based on position
  let localFeed = baseFeed + nx * 0.03;
  let localKill = baseKill + ny * 0.015;
  return vec2f(
    clamp(localFeed, 0.01, 0.1),
    clamp(localKill, 0.03, 0.07)
  );
}


// Main Compute Shader
@compute
@workgroup_size(8,8)
fn cs( @builtin(global_invocation_id) _cell:vec3u ) {
  
  // Convert to signed integers for math
  let cell = vec3i(_cell);

  // Get the array index for this pixel
  let i = index( cell.x, cell.y );

  // Step 1: Read current chemical concentrations
  let A = statein[i];
  let B = statein[i + 1];

  // Step 2: Get style map parameters
  let params = getStyleParams( cell.x, cell.y, feed, kill );
  let localFeed = params.x;
  let localKill = params.y;

  let dt = 1.0; // time step

  // Steps 3: Compute the Laplacians for diffusion
  let lapA = laplacianA( cell.x, cell.y );
  let lapB = laplacianB( cell.x, cell.y );

  // Step 4: Compute the reaction-diffusion equations
  let reaction = A * B * B;
  let newA = A + (Da * lapA - reaction + localFeed * (1.0 - A));
  let newB = B + (Db * lapB + reaction - (localKill + localFeed) * B);

  // Step 5: Clamp the new values to [0, 1]
  let clampedA = clamp( newA, 0.0, 1.0 );
  let clampedB = clamp( newB, 0.0, 1.0 );

  // Step 6: Write the new values to the output buffer
  stateout[i] = clampedA;
  stateout[i + 1] = clampedB;

}
