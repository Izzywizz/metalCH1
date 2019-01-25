import PlaygroundSupport
import MetalKit

//access GPU device
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("GPU is not supported")
}

//create a view, MTKView is simlar to UIView on iOS, its just window to the world
let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)

//a creame colour bg view
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)

/*Metal I/O - is framework whose sole purpose is to important models from Blender/ Maya and setup buffers for rendering.
 For this example we are simply loading a primitive 3D model from MetalIO helper libaries
 */


//1 - manage memory for the mesh data
//2 - create spehere using metal I/O helper method with specified size and vertex info and it loads the info into buggers
//3 - convert metal I/O mesh to a mesh that metalKit mesh can understanding.

let allocator = MTKMeshBufferAllocator(device: device) //1
let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75],
                      segments: [100, 100], inwardNormals: false,
                      geometryType: .triangles, allocator: allocator)//2
let mesh = try MTKMesh(mesh: mdlMesh, device: device)//3


/* Create a command queue, which orangises command buffers whom organised render command encoders,
 who actaully send the commands to the GPU for each frame*/

//This command queue should be setup at the start along and you should use the SAME device/ command queue
guard let commandQueue = device.makeCommandQueue() else { fatalError("Could not create a command queue") }

/*Remember that on each frame, you create a commamd buffer and this points to at least one render command encoder (the thing that sends instructions to the GPU). These are lightweight objs that point to other objs involved in shader/ vertex funcs and pipeline states */

// A shader func are small programs that run on the GPU
//creating shader func in c++, these programs run directly on the GPU: vertex_main - manipulate vertex positions, fragment_main - pixel colour

let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {

float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
    return vertex_in.position;
}

fragment float4 fragment_main() {
    return float4(1,0,0,1);
}
"""

//(below) setup metal lib that contains the 2 func above
let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

/*Pipeline States - Tells the GPU that nothing changes untill this piepline state does, all about efficentcy.
 Controls - pixel format/ whether to redner depth
 You don't create the pipeline state directly, you do this through a DESCRIPTOR that has the relevant properties you change.
 */

// recall that a descriptor is needed to control the piepline state; so we setup the correct shader funcs and a vertex descriptor.
// the vertex descriptor tells the metal buffer how the vertex should be laid out, metal I/O already had one ready for us with the sphere mesh
let descriptor = MTLRenderPipelineDescriptor()
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
descriptor.vertexFunction = vertexFunction
descriptor.fragmentFunction = fragmentFunction
descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

//pipelinState takes up processing time, so think one-time setup! Though you may need multiple pipeleines for different shader funcs/ vertex layouts
let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)


/* Rendering - per frame from this point
 1) A cmd buffer, stores all the cmds that you'll ask of the GPU
 2) This view's render pass descriptor holds data on render destinations known as Attachments.
    Each attachemnt will need info on which texture to store and whether to keep it through the piepline process.
    This view render pass descriptor is used to make the render command encoder.
 3) Render command encoder, holds all the neccasry info we send to the GPU so that it can draw the vertices, notice it uses the previous descriptor!
 */

guard let commmandBuffer = commandQueue.makeCommandBuffer(), //1

let descriptor = view.currentRenderPassDescriptor, //2
let renderEncoder = commmandBuffer.makeRenderCommandEncoder(descriptor: descriptor) //3
else { fatalError() }

// Pass on the Pipeline state to the render encoder
renderEncoder.setRenderPipelineState(pipelineState)

//verticles info is stored in that sphere mesh we made earlier, we pass this LIST on to the render encoder
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
// Set starting place of vertex using offset and index

/*Meshes and SUB-meshes
 A mesh is made up of submeshes, think about how a car is made into a 3D model, shiny new bonet paint, lovely glass windows and rubber tires.
 These are all sub-meshes and material types. Bsaically different material types, you can render one vertex multiple times if so wish.
 This sphere only has 1 sub-mesh
 */
guard let submesh = mesh.submeshes.first else { fatalError() }

/*
 Darwing the shape
 Tell the GPU to render the vertex buffer and make it up of triangles placed in the correct order via the sub-mesh index info (taken above)
 No rendering is done at this point, the GPU must have all command buffer commands in order to do this.
 */

renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)

/*
 Completing the Render commands to the render command encoder
 1) Tell the render command encoder that no more drawing is going to happen
 2) MTKView is backed by Core Animation metal layer, making it possible to draw textures via metal
 3) ASk the Command buffer to present the MTKView drawable and commit these instrcutions to the GPU 

 */
renderEncoder.endEncoding() //1
guard let drawable = view.currentDrawable else { fatalError() } //2
commmandBuffer.present(drawable) //3
commmandBuffer.commit()

PlaygroundPage.current.liveView = view
