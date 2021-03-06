// Multiple cellular automata interleaved with periodic processes of reorganisation:
// * randomly move some tiles
// * fill all tiles with their dominant colour
// * rearrange all tiles in circular order
// * sort all rows by colour
//
// On each iteration: advance CA. After n iterations: reorganise.
//
// Martin Dittus, Feb 2012

import processing.video.*;

int d = 200; // CA size
float cellSize = 2.4; // in pixels
int n = 11;  // reorganise after n iterations
int counter = 0;

float drawScale = 2.0;

List<CA> cas = new ArrayList<CA>();

MovieMaker mm;

void setup() {
  size(1920, 1080);
  frameRate(10);
  colorMode(HSB);

  cas.add(new CA(d, n));
  cas.add(new RandCA(d, n, 4, round(d*d * 0.01)));
  cas.add(new RandCA(d, n, 4, round(d*d * 0.40)));

  cas.add(new FillCA(d, n, 2));
  cas.add(new FillCA(d, n, 4));
  cas.add(new FillCA(d, n, 5));

  cas.add(new CircularCA(d, n, 2));
  cas.add(new CircularCA(d, n, 4));
  cas.add(new CircularCA(d, n, 5));

  cas.add(new RowCA(d, n, 1));
  cas.add(new RowCA(d, n, 2));
  cas.add(new RowCA(d, n, 4));
  
  reset();
}

void reset() {
  float fillRate = random(1);// 0.7 + random(0.2);
  for (CA ca : cas) {
    ca.reset(fillRate);
  }
  counter = 0;
}

void draw() {
  println(frameCount);
  
  int totalChangeCount = 0;

  noStroke();
  noSmooth();

  // Advance & draw CAs
  int x = 0;
  int y = 0;
  for (CA ca : cas) {
    ca.advance();

    drawCA(ca, x, y, cellSize);

    // Rate of change
    float rate = (float)ca.getChangedCellCount() / (d * d);
    drawRate(x, y, d*cellSize, rate);

    totalChangeCount += ca.getChangedCellCount();
    print(ca.getChangedCellCount() + " ");

    // next slot
    y += cellSize * d;
    if (y >= height) {
      y = 0;
      x += cellSize * d;
    }
  }
  println();

  // Reorg counter
  if ((++counter) % n == 0) {
      counter = 0;
  }
  
  smooth();
  noFill();
  drawCounter(width-50, 50, 30 * drawScale, (float)counter/n);
  
  // Record
  if (mm!=null) {
    mm.addFrame();
  }

  // Stagnated?
  if (totalChangeCount < 10) {
    println("Stagnated. Resetting...");
    reset();
  }
}

// Draw rate of change of a CA
// x, y: top left corner of CA
// rate: [0..1]
void drawRate(int x, int y, float h, float rate) {
  fill(255/4, 255, 200, 200); // green
  rect(x, y + rate * h, 5, (1-rate) * h);
}

// Draw reorganisation countdown 
// x, y: position
// r: radius
// counter: [0..1]
void drawCounter(int x, int y, float r, float counter) {
  strokeWeight(5 * drawScale);

  stroke(0, 0, 255, 150); // white
  ellipse(x, y, r, r);

  stroke(255/4, 255, 200, 200); // green
  if (counter==0) {
    ellipse(x, y, r, r);
  } else {
    arc(x, y, r, r, -PI/2, -PI/2 + 2*PI * counter);
  }
} 

void drawCA(CA ca, int x, int y, float cellSize) {
  for (int i=0; i<ca.cells.length; i++) {
    for (int j=0; j<ca.cells[i].length; j++) {
      fill(0, 0, ca.cells[i][j].present * 255);
      rect(x + i * cellSize, y + j * cellSize, cellSize, cellSize);
    }
  }
}

void keyPressed() {
  switch (key) {
    case ' ': reset(); break;
    case 'r':
      if (mm==null) {
        startRecording();
      } else {
        stopRecording();
      }
      break;
  }
}

void stop() {
  stopRecording();
}

void startRecording() {
  println("Starting recording...");
  mm = new MovieMaker(this, width, height, 
    "recording-" + System.currentTimeMillis() + ".mov",
    10, MovieMaker.MOTION_JPEG_B, MovieMaker.BEST);
}

void stopRecording() {
  println("Stopping recording.");
  if (mm!=null) {
    mm.finish();
    mm = null;
  }
}

class Cell {
  float present, future;
  
  Cell() {
    present = 0;
    future = 0;
  }
}

/**
 * General CA.
 */
class CA {
  public Cell[][] cells;
  public int n;
  public int stepCounter = 0;
  private int changedCellCount = 0; // cells changed since last iteration
  
  public CA(int d, int n) {
    cells = new Cell[d][d];
    this.n = n;
  }
  
  // fillRate [0..1] of 'present' values.
  public void reset(float fillRate) {
    seed(fillRate);
    stepCounter = 0;
  }
  
  protected void seed(float fillRate) {
    for (int i=0; i<cells.length; i++) {
      for (int j=0; j<cells[i].length; j++) {
        cells[i][j] = new Cell();
        if (random(1) <= fillRate) {
          cells[i][j].present = 1;
        } else {
          cells[i][j].present = 0;
        }
      }
    }
  }
  
  // Computes new state of 'future' values.
  public void advance() {
    advanceCA();
    apply();
    if ((++stepCounter) % n == 0) {
      stepCounter = 0;
      reorganise();
    }
  }
  
  protected void advanceCA() {
    for (int i=1; i<cells.length-1; i++) {
      for (int j=1; j<cells[i].length-1; j++) {
        float localSum = 
          cells[i-1][j].present +
          cells[i][j-1].present +
          cells[i+1][j].present +
          cells[i][j+1].present;
        
          if (localSum < 2) {
            cells[i][j].future = 0;
          } else if (localSum >= 2 && localSum < 3) {
            cells[i][j].future = 0;
          } else if (localSum >= 3 && localSum < 4) {
            cells[i][j].future = cells[i][j].present;
          } else if (localSum>=4) {
            cells[i][j].future = 1;
          }
          if (cells[i][j-1].present +
            cells[i+1][j].present == 2) {
//            cells[i][j].future = (random(1) > 0.5 ? 1 : 0);
          } else if (cells[i-1][j].present +
            cells[i][j+1].present == 0) {
            cells[i][j].future = cells[i][j].present;
          }
//        if (localSum <= 0) {
//          cells[i][j].future = 0;
//        } else if (localSum > 0 && localSum < 2) {
//          cells[i][j].future = 0;
//        } else if (localSum >= 2 && localSum < 3) {
//          cells[i][j].future = 1;
//        } else if (localSum >= 3 && localSum < 4) {
//          cells[i][j].future = cells[i][j].present;
//        } else if (localSum>=4) {
//          cells[i][j].future = 1;
//        }
      }
    }
  }
  
  protected void apply() {
    changedCellCount = 0;
    for (int i=1; i<cells.length-1; i++) {
      for (int j=1; j<cells[i].length-1; j++) {
        if (cells[i][j].present != cells[i][j].future) {
          changedCellCount++;
        }
        cells[i][j].present = cells[i][j].future;
      }
    }
  }
  
  public int getChangedCellCount() {
    return changedCellCount;
  }

  protected void reorganise() {
    // nop
  }
}

/**
 * Implements tile splitting.
 */
abstract class TiledCA extends CA {
  
  int xs, ys;
  int numX, numY;

  public TiledCA(int d, int n, int xs, int ys) {
    super(d, n);
    this.xs = xs;
    this.numX = d / xs;
    this.ys = ys;
    this.numY = d / ys;
  }
  
  protected void reorganise() {
    List<Cell[][]> tiles = getTiles(xs, ys);
    applyTiles(reorganiseTiles(tiles));
  }

  // To be implemented by subclasses. 
  abstract protected List<Cell[][]> reorganiseTiles(List<Cell[][]> tiles);

  // xs: tile width
  // ys: tile height
  protected List<Cell[][]> getTiles(int xs, int ys) {
    List<Cell[][]> tiles = new ArrayList<Cell[][]>();
    for (int y=0; y<d/ys; y++) {
      for (int x=0; x<d/xs; x++) {
        tiles.add(getTile(
          x*xs, y*ys, 
          xs, ys
          ));
      }
    }
    return tiles;
  }

  protected Cell[][] getTile(int x, int y, int w, int h) {
    Cell[][] tile = new Cell[w][h];
    for (int i=0; i<w; i++) {
      for (int j=0; j<h; j++) {
        tile[i][j] = cells[x+i][y+j];
      }
    }
    return tile;
  }

  protected void applyTiles(List<Cell[][]> tiles) {
    tiles = new ArrayList<Cell[][]>(tiles); // clone
    for (int y=0; y<numY; y++) {
      for (int x=0; x<numX; x++) {
        applyTile(
          tiles.remove(0),
          x * xs, y * ys
          );
      }
    }
  }

  protected void applyTile(Cell[][] tile, int x, int y) {
    for (int i=0; i<tile.length; i++) {
      for (int j=0; j<tile[i].length; j++) {
        cells[x+i][y+j] = tile[i][j];
      }
    }
  }

  // Calculate sum of cells.
  protected int sum(Cell[][] tile) {
    int n = 0;
    for (int i=0; i<tile.length; i++) {
      for (int j=0; j<tile[i].length; j++) {
        n += tile[i][j].present;
      }
    }
    return n;
  }
}

/**
 * Random tile movement, using square tiles.
 */
class RandCA extends TiledCA {
  
  int numMovements;

  public RandCA(int d, int n, int tileSize, int numMovements) {
    super(d, n, tileSize, tileSize);
    this.numMovements = numMovements;
  }

  protected List<Cell[][]> reorganiseTiles(List<Cell[][]> tiles) {
    // Move a few blocks to random new positions
    for (int n=0; n<numMovements; n++) {
      tiles.add(
        (int)random(tiles.size()),
        tiles.remove((int)random(tiles.size())));
    }
    return tiles;
  }
  
}

/**
 * Fill tile with dominant colour, using square tiles.
 */
class FillCA extends TiledCA {
  
  public FillCA(int d, int n, int tileSize) {
    super(d, n, tileSize, tileSize);
  }

  protected List<Cell[][]> reorganiseTiles(List<Cell[][]> tiles) {
    int numCells = xs * ys;
    for (Cell[][] tile : tiles) {
      int sum = sum(tile);
      if (sum > numCells / 2) { // > 50% of cells are filled
        fill(tile, 1);
      } else {
        fill(tile, 0);
      }
    }
    return tiles;
  }
  
  protected void fill(Cell[][] tile, float value) {
    for (int i=0; i<tile.length; i++) {
      for (int j=0; j<tile[i].length; j++) {
        tile[i][j].present = value;
      }
    }
  }
  
}

/**
 * Circular tile reorganisation, using square tiles.
 */
class CircularCA extends TiledCA {

  public CircularCA(int d, int n, int tileSize) {
    super(d, n, tileSize, tileSize);
  }

  protected List<Cell[][]> reorganiseTiles(List<Cell[][]> tiles) {
    // Sort by fill state
    Collections.sort(tiles, new Comparator<Cell[][]>(){
      public int compare(Cell[][] o1, Cell[][] o2) {
        return sum(o2) - sum(o1);
      }
    });
    return tiles;
  }
  
  // Reconstruct in circular order
  protected void applyTiles(List<Cell[][]> tiles) {
    float maxDist = sqrt(numX/2 * numX/2 + numY/2 * numY/2);
    for (int y=0; y<numY; y++) {
      for (int x=0; x<numX; x++) {
        float dist = sqrt((y-numY/2)*(y-numY/2) + (x-numX/2)*(x-numX/2));
        float nDist = dist / maxDist; // [0..1]
        // Now pick from list based on distance from centre:
        applyTile(
          tiles.remove(round(nDist * (tiles.size()-1))),
          x*xs, y*ys
          );
      }
    }
  }
  
}

/**
 * Row reorganisation, using one tile per cell row.
 */
class RowCA extends TiledCA {

  public RowCA(int d, int n, int height) {
    super(d, n, d, height);
  }

  protected List<Cell[][]> reorganiseTiles(List<Cell[][]> tiles) {
    // Sort by fill state
    Collections.sort(tiles, new Comparator<Cell[][]>(){
      public int compare(Cell[][] o1, Cell[][] o2) {
        return sum(o2) - sum(o1);
      }
    });
    return tiles;
  }
}
