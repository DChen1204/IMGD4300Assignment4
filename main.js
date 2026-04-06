import { default as seagulls } from './gulls.js'

const sg      = await seagulls.init(),
      frag    = await seagulls.import( './frag.wgsl' ),
      compute = await seagulls.import( './compute.wgsl' ),
      render  = seagulls.constants.vertex + frag,
      width   = window.innerWidth,
      height  = window.innerHeight,
      size    = width * height


// Create a seed pattern
// This function creates multiple random circles
function createState() {      

  const state = new Float32Array( size * 2 )
  
  // Initialize the state array 
  for( let i = 0; i < size; i++ ) {
    state[ i * 2 ] = 1.0 // a
    state[ i * 2 + 1 ] = 0.0 // b
  }

  // Number of circles
  const numCircles = Math.floor( Math.random()* 11) + 20 

  // For every circle,
  for (let c = 0; c < numCircles; c++) {
    
    // Randomize the position and radius 
    const cx = Math.random() * width
    const cy = Math.random() * height
    const radius = Math.random() * 30 + 5

    // Check every pixel if it is inside the circle
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {

        // Calculate the distance of the pixel from the center of the circle
        // If the distance is less than the radius, then the pixel is inside the circle
        const dx = x - cx
        const dy = y - cy
        const dist = Math.sqrt(dx * dx + dy * dy)
        if (dist < radius) {
          const i = (y * width + x) * 2
          state[i] = 0.0 
          state[i + 1] = 1.0 
        }

      }
    }

  }

  return state;
}

// Resolution
const res = sg.uniform([ width, height ])

// Simulation parameters
// Get saved parameters from localStorage, or use defaults if not available
const savedFeed = localStorage.getItem('savedFeed')
const savedKill = localStorage.getItem('savedKill')
const savedDa = localStorage.getItem('savedDa')
const savedDb = localStorage.getItem('savedDb')
const feed = sg.uniform( savedFeed ? parseFloat(savedFeed) : 0.055 )
const kill = sg.uniform( savedKill ? parseFloat(savedKill) : 0.062 )
const Da = sg.uniform( savedDa ? parseFloat(savedDa) : 1.0 )
const Db = sg.uniform( savedDb ? parseFloat(savedDb) : 0.5 )

// Ping-pong buffers 
const initialState = createState()
const statebuffer1 = sg.buffer(  initialState )
const statebuffer2 = sg.buffer(  initialState )

// Render pass
// Read from the current state buffer and write to the screen
const renderPass = await sg.render({
  shader: render,
  data: [
    res,
    sg.pingpong( statebuffer1, statebuffer2 )
  ]
})

// Compute pass
// Read from the current state buffer and write to the next state buffer
const computePass = sg.compute({
  shader: compute,
  data: [ 
    res, 
    feed,
    kill,
    Da,
    Db,
    sg.pingpong( statebuffer1, statebuffer2 )
  ],
  dispatchCount:  [Math.ceil(width / 8), Math.ceil(height/8), 1]
})

// Run the simulation
sg.run( computePass, renderPass )

// UI Event Listeners 
const feedSlider = document.querySelector('#feedRateSlider')
const killSlider = document.querySelector('#killRateSlider')
const daSlider   = document.querySelector('#daSlider')
const dbSlider   = document.querySelector('#dbSlider')
const feedValue  = document.querySelector('#feedRateValue')
const killValue  = document.querySelector('#killRateValue')
const daValue    = document.querySelector('#daValue')
const dbValue    = document.querySelector('#dbValue')
const randomSeedButton = document.querySelector('#randomSeedButton')

// Restore slider and text values 
feedSlider.value = feed.value
feedValue.textContent = feed.value.toFixed( 3 )
killSlider.value = kill.value
killValue.textContent = kill.value.toFixed( 3 )
daSlider.value = Da.value
daValue.textContent = Da.value.toFixed( 2 )
dbSlider.value = Db.value
dbValue.textContent = Db.value.toFixed( 2 )
document.querySelector('.controls').classList.add('visible')

// When sliders change, update the uniform values and save to localStorage
feedSlider.oninput = () => {
  feed.value = parseFloat( feedSlider.value )
  feedValue.textContent = feed.value.toFixed( 3 )
  localStorage.setItem( 'savedFeed', feed.value.toString() )
}

killSlider.oninput = () => {
  kill.value = parseFloat( killSlider.value )
  killValue.textContent = kill.value.toFixed( 3 )
  localStorage.setItem( 'savedKill', kill.value.toString() )
}

daSlider.oninput = () => {
  Da.value = parseFloat( daSlider.value )
  daValue.textContent = Da.value.toFixed( 2 )
  localStorage.setItem( 'savedDa', Da.value.toString() )
}

dbSlider.oninput = () => {
  Db.value = parseFloat( dbSlider.value )
  dbValue.textContent = Db.value.toFixed( 2 )
  localStorage.setItem( 'savedDb', Db.value.toString() )
}

randomSeedButton.onclick = () => {
  location.reload()
}



